import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';

/// Screen for adding new projectors to the system
class AddProjectorScreen extends ConsumerStatefulWidget {
  const AddProjectorScreen({super.key});

  @override
  ConsumerState<AddProjectorScreen> createState() => _AddProjectorScreenState();
}

class _AddProjectorScreenState extends ConsumerState<AddProjectorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serialNumberController = TextEditingController();
  final _modelNameController = TextEditingController();
  final _projectorNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _statusController = TextEditingController();
  
  bool _isLoading = false;
  bool _isScanning = false;
  String _selectedStatus = AppConstants.statusAvailable;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _statusController.text = _selectedStatus;
    // Initialize scanner when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScanner();
    });
  }

  @override
  void dispose() {
    _serialNumberController.dispose();
    _modelNameController.dispose();
    _projectorNameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _statusController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Projector'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.keyboard), text: 'Manual Entry'),
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan Barcode'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildManualEntryForm(),
            _buildScanForm(),
          ],
        ),
      ),
    );
  }

  /// Build manual entry form
  Widget _buildManualEntryForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.largePadding),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 64,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Add New Projector',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the projector details below to add it to the system',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppConstants.largePadding),
          
          // Serial Number Field
          TextFormField(
            controller: _serialNumberController,
            decoration: const InputDecoration(
              labelText: 'Serial Number *',
              hintText: 'Enter projector serial number',
              prefixIcon: Icon(Icons.qr_code),
              helperText: 'This should match the barcode/QR code on the projector',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Serial number is required';
              }
              if (value.trim().length < 3) {
                return 'Serial number must be at least 3 characters';
              }
              return null;
            },
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          
          const SizedBox(height: AppConstants.defaultPadding),
          
          // Model Name Field
          TextFormField(
            controller: _modelNameController,
            decoration: const InputDecoration(
              labelText: 'Model Name *',
              hintText: 'Enter projector model name',
              prefixIcon: Icon(Icons.model_training),
              helperText: 'e.g., Epson PowerLite, BenQ TH685P',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Model name is required';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppConstants.defaultPadding),
          
          // Projector Name Field
          TextFormField(
            controller: _projectorNameController,
            decoration: const InputDecoration(
              labelText: 'Projector Name *',
              hintText: 'Enter projector display name',
              prefixIcon: Icon(Icons.label),
              helperText: 'e.g., Lab A Projector, Conference Room 1',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Projector name is required';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppConstants.defaultPadding),
          
          // Location Field
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location',
              hintText: 'Enter projector location',
              prefixIcon: Icon(Icons.location_on),
              helperText: 'e.g., Building A, Floor 2, Room 201',
            ),
          ),
          
          const SizedBox(height: AppConstants.defaultPadding),
          
          // Status Field
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status *',
              prefixIcon: Icon(Icons.info_outline),
              helperText: 'Select the current status of the projector',
            ),
            items: [
              DropdownMenuItem(
                value: AppConstants.statusAvailable,
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.statusAvailable,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(AppConstants.statusAvailable),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: AppConstants.statusIssued,
                child: Row(
                  children: [
                    Icon(
                      Icons.send,
                      color: AppTheme.statusIssued,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(AppConstants.statusIssued),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: AppConstants.statusMaintenance,
                child: Row(
                  children: [
                    Icon(
                      Icons.build,
                      color: AppTheme.statusMaintenance,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(AppConstants.statusMaintenance),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedStatus = value;
                  _statusController.text = value;
                });
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Status is required';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppConstants.defaultPadding),
          
          // Notes Field
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Enter any additional notes',
              prefixIcon: Icon(Icons.note),
              helperText: 'Optional: Any special instructions or details',
            ),
            maxLines: 3,
          ),
          
          const SizedBox(height: AppConstants.largePadding),
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Adding Projector...'),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add),
                        SizedBox(width: 8),
                        Text('Add Projector'),
                      ],
                    ),
            ),
          ),
          
          const SizedBox(height: AppConstants.defaultPadding),
          
          // Cancel Button
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  /// Build scan form
  Widget _buildScanForm() {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.largePadding),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            border: Border.all(
              color: AppTheme.accentColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 64,
                color: AppTheme.accentColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Scan Projector Barcode',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan the barcode/QR code to automatically fill the form',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.defaultPadding),

        // Scanner View
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: AppTheme.accentColor, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius - 2),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onBarcodeDetected,
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
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppTheme.errorColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              error.errorDetails?.message ?? 'Unknown error occurred',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
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
                  if (_isScanning)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.accentColor, width: 3),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 64,
                              color: Colors.white,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Position barcode within frame',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Scanning...',
                              style: TextStyle(
                                color: Colors.white70,
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
          ),
        ),

        const SizedBox(height: AppConstants.defaultPadding),

        // Control Buttons
        Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? _stopScanner : _startScanner,
              icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
              label: Text(_isScanning ? 'Stop Scanner' : 'Start Scanner'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanning ? AppTheme.errorColor : AppTheme.accentColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Initialize scanner
  void _initializeScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    // Don't start automatically, let user control with button
  }

  /// Start scanner
  void _startScanner() {
    if (_scannerController != null && !_isScanning) {
      _scannerController!.start();
      setState(() {
        _isScanning = true;
      });
    }
  }

  /// Stop scanner
  void _stopScanner() {
    if (_scannerController != null && _isScanning) {
      _scannerController!.stop();
      setState(() {
        _isScanning = false;
      });
    }
  }

  /// Handle barcode detection
  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!_isScanning) return;

    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

    // Stop scanning
    _stopScanner();

    // Fill the serial number field
    _serialNumberController.text = barcode.rawValue!;

    // Show success message and switch to manual tab
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Barcode scanned: ${barcode.rawValue}'),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    // Switch to manual tab after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        DefaultTabController.of(context).animateTo(0);
      }
    });
  }

  /// Submit the form to add the projector
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      
      // Create new projector
      final projector = Projector(
        id: '', // Will be set by Firestore
        serialNumber: _serialNumberController.text.trim().toUpperCase(),
        modelName: _modelNameController.text.trim(),
        projectorName: _projectorNameController.text.trim(),
        status: _selectedStatus,
        location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add to Firestore
      final projectorId = await firestoreService.addProjector(projector);
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Projector added successfully! ID: $projectorId'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Navigate back
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding projector: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
