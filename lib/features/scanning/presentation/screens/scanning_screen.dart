import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';

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
  Projector? _scannedProjector;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  /// Handle barcode detection
  void _onDetect(BarcodeCapture capture) {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scannedCode = capture.barcodes.first.rawValue;
    });

    _processScannedCode();
  }

  /// Process the scanned barcode/QR code
  Future<void> _processScannedCode() async {
    if (_scannedCode == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final projector = await firestoreService.getProjectorBySerialNumber(
        _scannedCode!,
      );

      setState(() {
        _scannedProjector = projector;
        _isLoading = false;
      });

      if (projector != null) {
        _showProjectorInfo(projector);
      } else {
        _showProjectorNotFound();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    // Reset scanning state after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  /// Show projector information dialog
  void _showProjectorInfo(Projector projector) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projector Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Serial: ${projector.serialNumber}'),
            const SizedBox(height: 8),
            Text('Status: ${projector.status}'),
            if (projector.lastIssuedTo != null) ...[
              const SizedBox(height: 8),
              Text('Last Issued To: ${projector.lastIssuedTo}'),
            ],
            if (projector.lastIssuedDate != null) ...[
              const SizedBox(height: 8),
              Text('Last Issued: ${_formatDate(projector.lastIssuedDate!)}'),
            ],
          ],
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

  /// Show projector not found dialog
  void _showProjectorNotFound() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projector Not Found'),
        content: Text('No projector found with serial number: $_scannedCode'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Toggle scanner
  void _toggleScanner() {
    if (_scannerController?.isStarting == true) return;

    if (_isScanning) {
      _scannerController?.stop();
      setState(() {
        _isScanning = false;
      });
    } else {
      _scannerController?.start();
      setState(() {
        _isScanning = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Scanner View
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),

                // Scanning overlay
                if (_isScanning)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.accentColor, width: 3),
                    ),
                    child: const Center(
                      child: Text(
                        'Scanning...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Loading indicator
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          // Control Panel
          Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            color: AppTheme.backgroundColor,
            child: Column(
              children: [
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
                      border: Border.all(color: AppTheme.textTertiary),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scanned Code:',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _scannedCode!,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontFamily: 'monospace', fontSize: 16),
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
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Navigate to manual entry screen
                        },
                        icon: const Icon(Icons.keyboard),
                        label: const Text('Manual Entry'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
