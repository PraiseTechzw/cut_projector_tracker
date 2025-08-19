import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../shared/models/projector.dart';

/// Scanning screen for barcode/QR code detection
class ScanningScreen extends ConsumerStatefulWidget {
  final String? purpose; // 'issue' or 'return'

  const ScanningScreen({super.key, this.purpose});

  @override
  ConsumerState<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends ConsumerState<ScanningScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  MobileScannerController? _scannerController;
  bool _isScanning = false;
  bool _hasPermission = false;
  bool _isLoading = false;
  bool _isPermissionLoading = false;
  bool _permissionPermanentlyDenied = false;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
    _setupAnimations();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-check permissions when app becomes active (user returns from settings)
    if (state == AppLifecycleState.resumed && _permissionPermanentlyDenied) {
      _initializeScanner();
    }
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeScanner() async {
    setState(() {
      _isPermissionLoading = true;
      _errorMessage = null;
      _permissionPermanentlyDenied = false;
    });

    try {
      final permissionService = ref.read(permissionServiceProvider);
      final result = await permissionService.initializeCameraPermission();
      
      switch (result) {
        case CameraPermissionResult.granted:
          _setupCamera();
          break;
        case CameraPermissionResult.denied:
          setState(() {
            _isPermissionLoading = false;
            _errorMessage = 'Camera permission is required to scan projectors';
          });
          break;
        case CameraPermissionResult.permanentlyDenied:
          setState(() {
            _isPermissionLoading = false;
            _permissionPermanentlyDenied = true;
            _errorMessage = 'Camera permission permanently denied. Please enable it in app settings.';
          });
          break;
        case CameraPermissionResult.restricted:
          setState(() {
            _isPermissionLoading = false;
            _errorMessage = 'Camera access is restricted on this device';
          });
          break;
        case CameraPermissionResult.error:
          setState(() {
            _isPermissionLoading = false;
            _errorMessage = 'Error requesting camera permission';
          });
          break;
      }
    } catch (e) {
      setState(() {
        _isPermissionLoading = false;
        _errorMessage = 'Error initializing camera: $e';
      });
    }
  }

  void _setupCamera() {
    try {
      setState(() {
        _hasPermission = true;
        _isPermissionLoading = false;
        _scannerController = MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          torchEnabled: false,
        );
      });
    } catch (e) {
      setState(() {
        _isPermissionLoading = false;
        _hasPermission = false;
        _errorMessage = 'Error initializing camera: $e';
      });
    }
  }

  Future<void> _openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open app settings: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final code = capture.barcodes.first.rawValue;
    if (code != null && code.isNotEmpty) {
      setState(() {
        _isScanning = false;
      });
      _lookupProjector(code);
    }
  }

  Future<void> _lookupProjector(String serialNumber) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final projector = await firestoreService.getProjectorBySerialNumber(
        serialNumber,
      );

      if (projector != null) {
        setState(() {
          _isLoading = false;
        });

        // If opened via push() (from issue/return screens), return directly
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(projector);
          return;
        }

        // Otherwise show the confirmation dialog
        _showProjectorFoundDialog(projector);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Projector not found in database';
        });

        // If opened via push(), show error and return
        if (Navigator.of(context).canPop()) {
          _showProjectorNotFoundDialog(serialNumber);
          return;
        }

        _showProjectorNotFoundDialog(serialNumber);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error looking up projector: $e';
      });

      // If opened via push(), show error and return
      if (Navigator.of(context).canPop()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error looking up projector: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        Navigator.of(context).pop();
        return;
      }
    }
  }

  void _showProjectorFoundDialog(Projector projector) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            const Text('Projector Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Serial: ${projector.serialNumber}'),
            Text('Status: ${projector.status}'),
            if (projector.lastIssuedTo != null)
              Text('Last Issued To: ${projector.lastIssuedTo}'),
            if (projector.lastIssuedDate != null)
              Text('Last Issued: ${_formatDate(projector.lastIssuedDate!)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanner();
            },
            child: const Text('Scan Another'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _proceedWithProjector(projector);
            },
            child: Text(
              widget.purpose == 'return' ? 'Return This' : 'Issue This',
            ),
          ),
        ],
      ),
    );
  }

  void _showProjectorNotFoundDialog(String serialNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            const Text('Projector Not Found'),
          ],
        ),
        content: Text(
          'The projector with serial number "$serialNumber" was not found in the database.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanner();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showEnhancedManualEntry() {
    final manualEntryController = TextEditingController();
    List<Projector> allProjectors = [];
    List<Projector> filteredProjectors = [];
    bool isLoading = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Load projectors if not loaded yet
          if (isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                final firestoreService = ref.read(firestoreServiceProvider);
                final projectorsStream = firestoreService.getProjectors();
                final projectors = await projectorsStream.first;
                setState(() {
                  allProjectors = projectors;
                  filteredProjectors = projectors;
                  isLoading = false;
                });
              } catch (e) {
                setState(() {
                  isLoading = false;
                });
              }
            });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.keyboard,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manual Entry & Select',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              'Enter serial number or select from available projectors',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search/Input Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: manualEntryController,
                    onChanged: (value) {
                      if (value.isEmpty) {
                        setState(() {
                          filteredProjectors = allProjectors;
                        });
                      } else {
                        setState(() {
                          filteredProjectors = allProjectors.where((projector) {
                            final searchLower = value.toLowerCase();
                            return projector.serialNumber
                                    .toLowerCase()
                                    .contains(searchLower) ||
                                projector.modelName.toLowerCase().contains(
                                  searchLower,
                                ) ||
                                projector.projectorName.toLowerCase().contains(
                                  searchLower,
                                );
                          }).toList();
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Search Projectors',
                      hintText: 'Enter serial number, model, or name...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.textTertiary.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.textTertiary.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppTheme.backgroundColor,
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),

                const SizedBox(height: 20),

                // Projectors List
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredProjectors.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No projectors found',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try adjusting your search terms',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredProjectors.length,
                            itemBuilder: (context, index) {
                              final projector = filteredProjectors[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.qr_code,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  title: Text(
                                    projector.serialNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (projector.modelName.isNotEmpty)
                                        Text('Model: ${projector.modelName}'),
                                      if (projector.projectorName.isNotEmpty)
                                        Text(
                                          'Name: ${projector.projectorName}',
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: projector.status == 'Available'
                                              ? Colors.green.withValues(
                                                  alpha: 0.1,
                                                )
                                              : Colors.orange.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          projector.status,
                                          style: TextStyle(
                                            color:
                                                projector.status == 'Available'
                                                ? Colors.green
                                                : Colors.orange,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    color: AppTheme.textSecondary,
                                    size: 16,
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    _proceedWithProjector(projector);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: BorderSide(
                              color: AppTheme.textTertiary,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              manualEntryController.text.trim().isNotEmpty
                              ? () {
                                  Navigator.of(context).pop();
                                  _lookupProjector(
                                    manualEntryController.text.trim(),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: const Text('Search & Select'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _proceedWithProjector(Projector projector) {
    // If opened from Issue/Return screens via push(), return the projector
    if (widget.purpose != null && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(projector);
      return;
    }

    // Otherwise, navigate directly based on selected action
    if (widget.purpose == 'return') {
      context.go('/return-projector', extra: {'projector': projector});
    } else {
      context.go('/issue-projector', extra: {'projector': projector});
    }
  }

  void _resetScanner() {
    setState(() {
      _errorMessage = null;
      _isScanning = true;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Scan Projector ${widget.purpose == 'return' ? 'for Return' : 'for Issue'}',
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Manual entry button for all cases
          IconButton(
            icon: const Icon(Icons.keyboard),
            onPressed: _showEnhancedManualEntry,
            tooltip: 'Manual Entry & Select',
          ),
          IconButton(
            icon: Icon(
              _scannerController?.torchEnabled == true
                  ? Icons.flash_on
                  : Icons.flash_off,
            ),
            onPressed: () {
              _scannerController?.toggleTorch();
            },
          ),
        ],
      ),
      body: _hasPermission ? _buildScanner() : _buildPermissionRequest(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        // Camera view
        MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
          onScannerStarted: (value) {
            setState(() {
              _isScanning = true;
            });
          },
        ),

        // Scanning overlay
        _buildScanningOverlay(),

        // Error message
        if (_errorMessage != null) _buildErrorMessage(),

        // Loading indicator
        if (_isLoading) _buildLoadingIndicator(),
      ],
    );
  }

  Widget _buildScanningOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryColor, width: 2),
        ),
        child: Column(
          children: [
            const Spacer(),

            // Scanning frame
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Corner indicators
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Scanning line
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: _pulseAnimation.value * 80,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          color: AppTheme.primaryColor,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Instructions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Position the barcode/QR code within the frame',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Looking up projector...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        _permissionPermanentlyDenied
                            ? Icons.settings
                            : Icons.camera_alt_outlined,
                        size: 64,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                _permissionPermanentlyDenied
                    ? 'Camera Access Needed'
                    : 'Camera Permission Required',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                _permissionPermanentlyDenied
                    ? 'Camera permission was denied. To scan projector codes, please enable camera access in your device settings.'
                    : 'This app needs camera access to scan projector barcodes and QR codes. Your privacy is important - the camera is only used for scanning.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              // Error message if any
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Action buttons
              if (_isPermissionLoading)
                Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Checking camera permission...',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              else if (_permissionPermanentlyDenied)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openAppSettings,
                        icon: const Icon(Icons.settings),
                        label: const Text('Open App Settings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _initializeScanner,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Check Again'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _initializeScanner,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Grant Camera Permission'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Go Back'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: BorderSide(color: AppTheme.textTertiary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 24),

              // Privacy note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.textTertiary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your privacy matters. Camera access is only used for scanning projector codes.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
