import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';
import '../../../issuance/presentation/screens/issue_projector_screen.dart';
import '../../../returns/presentation/screens/return_projector_screen.dart';

/// Screen for scanning projector barcodes/QR codes
class ScanningScreen extends ConsumerStatefulWidget {
  const ScanningScreen({super.key});

  @override
  ConsumerState<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends ConsumerState<ScanningScreen> {
  MobileScannerController? _scannerController;
  bool _isScanning = false;
  String? _scannedCode;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  final _manualEntryController = TextEditingController();
  final List<String> _recentScans = [];
  static const int _maxRecentScans = 5;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _manualEntryController.dispose();
    super.dispose();
  }

  /// Initialize the scanner controller
  void _initializeScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // Start scanning automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanner();
    });
  }

  /// Start the scanner
  void _startScanner() {
    if (_scannerController != null && !_isScanning) {
      _scannerController!.start();
      setState(() {
        _isScanning = true;
        _hasError = false;
        _errorMessage = '';
      });
    }
  }

  /// Stop the scanner
  void _stopScanner() {
    if (_scannerController != null && _isScanning) {
      _scannerController!.stop();
      setState(() {
        _isScanning = false;
      });
    }
  }

  /// Handle barcode detection
  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning || _isLoading) return;

    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

    // Provide haptic feedback
    HapticFeedback.mediumImpact();

    setState(() {
      _scannedCode = barcode.rawValue;
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    _processScannedCode();
  }

  /// Process the scanned barcode/QR code
  Future<void> _processScannedCode() async {
    if (_scannedCode == null) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final projector = await firestoreService.getProjectorBySerialNumber(
        _scannedCode!,
      );

      setState(() {
        _isLoading = false;
      });

      if (projector != null) {
        // Provide success feedback
        HapticFeedback.lightImpact();
        _addToRecentScans(_scannedCode!);
        _showProjectorInfo(projector);
      } else {
        // Provide error feedback
        HapticFeedback.heavyImpact();
        _showProjectorNotFound();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to fetch projector data: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    // Reset scanning state after delay to allow user to see the result
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _scannedCode = null;
          _isScanning = true;
        });
        // Restart scanner if it was stopped
        if (_scannerController != null) {
          _scannerController!.start();
        }
      }
    });
  }

  /// Process manual entry
  Future<void> _processManualEntry() async {
    final serialNumber = _manualEntryController.text.trim();
    if (serialNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a serial number'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _scannedCode = serialNumber;
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final projector = await firestoreService.getProjectorBySerialNumber(
        serialNumber,
      );

      setState(() {
        _isLoading = false;
      });

      if (projector != null) {
        // Provide success feedback
        HapticFeedback.lightImpact();
        _addToRecentScans(serialNumber);
        _showProjectorInfo(projector);
      } else {
        // Provide error feedback
        HapticFeedback.heavyImpact();
        _showProjectorNotFound();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to fetch projector data: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    _manualEntryController.clear();
  }

  /// Show manual entry dialog
  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.keyboard, color: AppTheme.accentColor, size: 24),
            const SizedBox(width: 8),
            const Text('Manual Entry'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the projector serial number manually:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _manualEntryController,
              decoration: InputDecoration(
                labelText: 'Serial Number',
                hintText: 'e.g., PROJ001',
                prefixIcon: const Icon(Icons.qr_code),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius,
                  ),
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _processManualEntry(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _manualEntryController.clear();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _processManualEntry,
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  /// Show projector information dialog
  void _showProjectorInfo(Projector projector) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successColor, size: 24),
            const SizedBox(width: 8),
            const Text('Projector Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Serial Number', projector.serialNumber),
            const SizedBox(height: 12),
            if (projector.modelName.isNotEmpty) ...[
              _buildInfoRow('Model', projector.modelName),
              const SizedBox(height: 12),
            ],
            if (projector.projectorName.isNotEmpty) ...[
              _buildInfoRow('Name', projector.projectorName),
              const SizedBox(height: 12),
            ],
            _buildInfoRow(
              'Status',
              projector.status,
              statusColor: _getStatusColor(projector.status),
            ),
            if (projector.location != null &&
                projector.location!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Location', projector.location!),
            ],
            if (projector.lastIssuedTo != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Last Issued To', projector.lastIssuedTo!),
            ],
            if (projector.lastIssuedDate != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Last Issued',
                _formatDate(projector.lastIssuedDate!),
              ),
            ],
            if (projector.notes != null && projector.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Notes', projector.notes!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScan();
            },
            child: const Text('Scan Another'),
          ),
          if (projector.status.toLowerCase() == 'available')
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToIssuance(projector);
              },
              icon: const Icon(Icons.send),
              label: const Text('Issue Projector'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
              ),
            ),
          if (projector.status.toLowerCase() == 'issued')
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToReturn(projector);
              },
              icon: const Icon(Icons.undo),
              label: const Text('Return Projector'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.statusAvailable,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  /// Show projector not found dialog
  void _showProjectorNotFound() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.warningColor, size: 24),
            const SizedBox(width: 8),
            const Text('Projector Not Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No projector found with serial number:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.textTertiary),
              ),
              child: Text(
                _scannedCode!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please check the serial number or contact an administrator.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScan();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  /// Build an info row for the dialog
  Widget _buildInfoRow(String label, String value, {Color? statusColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: statusColor ?? AppTheme.textPrimary,
              fontWeight: statusColor != null
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  /// Get status color based on projector status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return AppTheme.statusAvailable;
      case 'issued':
        return AppTheme.statusIssued;
      case 'maintenance':
        return AppTheme.statusMaintenance;
      default:
        return AppTheme.textPrimary;
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Navigate to issuance screen with projector data
  void _navigateToIssuance(Projector projector) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IssueProjectorScreen(projector: projector),
      ),
    );
  }

  /// Navigate to return screen with projector data
  void _navigateToReturn(Projector projector) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReturnProjectorScreen(projector: projector),
      ),
    );
  }

  /// Reset scan state
  void _resetScan() {
    setState(() {
      _scannedCode = null;
      _hasError = false;
      _errorMessage = '';
    });
    _startScanner();
  }

  /// Toggle scanner on/off
  void _toggleScanner() {
    if (_scannerController?.isStarting == true) return;

    if (_isScanning) {
      _stopScanner();
    } else {
      _startScanner();
    }
  }

  /// Toggle torch/flashlight
  void _toggleTorch() {
    if (_scannerController != null) {
      _scannerController!.toggleTorch();
    }
  }

  /// Add scan to recent history
  void _addToRecentScans(String serialNumber) {
    if (!_recentScans.contains(serialNumber)) {
      _recentScans.insert(0, serialNumber);
      if (_recentScans.length > _maxRecentScans) {
        _recentScans.removeLast();
      }
    }
  }

  /// Show recent scans dialog
  void _showRecentScansDialog() {
    if (_recentScans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No recent scans available'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.history, color: AppTheme.accentColor, size: 24),
            const SizedBox(width: 8),
            const Text('Recent Scans'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _recentScans.map((scan) {
            return ListTile(
              leading: const Icon(Icons.qr_code, color: AppTheme.accentColor),
              title: Text(scan),
              onTap: () {
                Navigator.of(context).pop();
                _manualEntryController.text = scan;
                _showManualEntryDialog();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Projector'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showManualEntryDialog,
            icon: const Icon(Icons.keyboard),
            tooltip: 'Manual Entry',
          ),
          IconButton(
            onPressed: _showRecentScansDialog,
            icon: const Icon(Icons.history),
            tooltip: 'Recent Scans',
          ),
          IconButton(
            onPressed: _toggleTorch,
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Toggle Torch',
          ),
        ],
      ),
      body: Column(
        children: [
          // Scanner View
          Expanded(
            child: Stack(
              children: [
                // Scanner
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppTheme.errorColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Scanner Error',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: AppTheme.errorColor),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.errorDetails?.message ??
                                'Unknown error occurred',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _initializeScanner,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Scanning overlay
                if (_isScanning && !_isLoading)
                  Container(
                    decoration: BoxDecoration(color: Colors.black54),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Scanning frame
                          Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppTheme.accentColor,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Stack(
                              children: [
                                // Corner indicators
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: AppTheme.accentColor,
                                          width: 4,
                                        ),
                                        left: BorderSide(
                                          color: AppTheme.accentColor,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: AppTheme.accentColor,
                                          width: 4,
                                        ),
                                        right: BorderSide(
                                          color: AppTheme.accentColor,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppTheme.accentColor,
                                          width: 4,
                                        ),
                                        left: BorderSide(
                                          color: AppTheme.accentColor,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppTheme.accentColor,
                                          width: 4,
                                        ),
                                        right: BorderSide(
                                          color: AppTheme.accentColor,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Center icon
                                Center(
                                  child: Icon(
                                    Icons.qr_code_scanner,
                                    size: 48,
                                    color: AppTheme.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Position barcode within frame',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.radio_button_checked,
                                  color: AppTheme.accentColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Scanning...',
                                  style: TextStyle(
                                    color: AppTheme.accentColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Loading indicator
                if (_isLoading)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Processing...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Success animation overlay
                if (_scannedCode != null && !_isLoading)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withValues(
                                alpha: 0.9,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Barcode Detected!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Processing projector information...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Control Panel
          Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Error Display
                if (_hasError) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadius,
                      ),
                      border: Border.all(color: AppTheme.errorColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppTheme.errorColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.errorColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Scanned Code Display
                if (_scannedCode != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadius,
                      ),
                      border: Border.all(color: AppTheme.accentColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.qr_code,
                              color: AppTheme.accentColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Scanned Code:',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accentColor,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _scannedCode!,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Control Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _toggleScanner,
                        icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                        label: Text(
                          _isScanning ? 'Stop Scanner' : 'Start Scanner',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning
                              ? AppTheme.errorColor
                              : AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showManualEntryDialog();
                        },
                        icon: const Icon(Icons.keyboard),
                        label: const Text('Manual Entry'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _toggleTorch,
                        icon: const Icon(Icons.flashlight_on),
                        label: const Text('Toggle Torch'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentColor,
                          side: BorderSide(color: AppTheme.accentColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showRecentScansDialog,
                        icon: const Icon(Icons.history),
                        label: const Text('Recent Scans'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentColor,
                          side: BorderSide(color: AppTheme.accentColor),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _resetScan,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Scanner'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(color: AppTheme.textTertiary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
