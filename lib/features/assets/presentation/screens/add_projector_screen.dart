import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';

/// Screen for adding new projectors to the system
class AddProjectorScreen extends ConsumerStatefulWidget {
  final String? initialSerialNumber;
  final String? initialModelName;
  final String? initialProjectorName;
  final String? initialStatus;
  final String? initialLocation;
  final String? initialNotes;
  final bool isEditing;

  const AddProjectorScreen({
    super.key,
    this.initialSerialNumber,
    this.initialModelName,
    this.initialProjectorName,
    this.initialStatus,
    this.initialLocation,
    this.initialNotes,
    this.isEditing = false,
  });

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

    // Pre-fill serial number if provided
    if (widget.initialSerialNumber != null) {
      _serialNumberController.text = widget.initialSerialNumber!;
    }

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
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Add Projector'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(icon: Icon(Icons.edit_note), text: 'Manual Entry'),
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan Barcode'),
            ],
          ),
        ),
        body: TabBarView(children: [_buildManualEntryForm(), _buildScanForm()]),
      ),
    );
  }

  /// Build manual entry form
  Widget _buildManualEntryForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Form Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit_note,
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
                          'Projector Details',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          'Enter the projector details below',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Enhanced Serial Number Field
              _buildEnhancedFormField(
                controller: _serialNumberController,
                label: 'Serial Number',
                hint: 'Enter projector serial number',
                icon: Icons.qr_code,
                helperText:
                    'This should match the barcode/QR code on the projector',
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
              const SizedBox(height: 20),

              // Enhanced Model Name Field
              _buildEnhancedFormField(
                controller: _modelNameController,
                label: 'Model Name',
                hint: 'Enter projector model name',
                icon: Icons.model_training,
                helperText: 'e.g., Epson PowerLite, BenQ TH685P',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Model name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Enhanced Projector Name Field
              _buildEnhancedFormField(
                controller: _projectorNameController,
                label: 'Projector Name',
                hint: 'Enter projector display name',
                icon: Icons.label,
                helperText: 'e.g., Lab A Projector, Conference Room 1',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Projector name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Enhanced Location Field
              _buildEnhancedFormField(
                controller: _locationController,
                label: 'Location',
                hint: 'Enter projector location',
                icon: Icons.location_on,
                helperText: 'e.g., Building A, Floor 2, Room 201',
                validator: null, // Optional field
              ),
              const SizedBox(height: 20),

              // Enhanced Status Field
              _buildEnhancedDropdownField(),
              const SizedBox(height: 20),

              // Enhanced Notes Field
              _buildEnhancedFormField(
                controller: _notesController,
                label: 'Notes',
                hint: 'Enter any additional notes',
                icon: Icons.note,
                helperText: 'Optional: Any special instructions or details',
                validator: null, // Optional field
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Enhanced Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius,
                          ),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Add Projector',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build enhanced form field
  Widget _buildEnhancedFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? helperText,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextCapitalization? textCapitalization,
    TextStyle? style,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (validator != null)
              Text(
                ' *',
                style: TextStyle(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (helperText != null) ...[
          Text(
            helperText,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          textCapitalization: textCapitalization ?? TextCapitalization.none,
          style: style,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textTertiary),
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: BorderSide(
                color: AppTheme.textTertiary.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: BorderSide(
                color: AppTheme.textTertiary.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: BorderSide(color: AppTheme.errorColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  /// Build enhanced dropdown field
  Widget _buildEnhancedDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Select the current status of the projector',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedStatus,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: BorderSide(
                color: AppTheme.textTertiary.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: BorderSide(
                color: AppTheme.textTertiary.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
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
                  const SizedBox(width: 12),
                  Text(AppConstants.statusAvailable),
                ],
              ),
            ),
            DropdownMenuItem(
              value: AppConstants.statusIssued,
              child: Row(
                children: [
                  Icon(Icons.send, color: AppTheme.statusIssued, size: 20),
                  const SizedBox(width: 12),
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
                  const SizedBox(width: 12),
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
      ],
    );
  }

  /// Build scan form
  Widget _buildScanForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Scan Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: AppTheme.accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Projector Barcode',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Position the barcode within the scanner frame',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Enhanced Scanner Container
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    // Scanner
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: _onBarcodeDetected,
                      errorBuilder: (context, error, child) {
                        return Container(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: AppTheme.errorColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Scanner Error',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppTheme.errorColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  error.errorDetails?.message ??
                                      'Unknown error occurred',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _initializeScanner,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Enhanced Scanning Overlay
                    if (_isScanning)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.accentColor,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.9,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 3,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Scanning...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Enhanced Scanner Controls
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isScanning
                                  ? _stopScanner
                                  : _startScanner,
                              icon: Icon(
                                _isScanning ? Icons.stop : Icons.play_arrow,
                              ),
                              label: Text(
                                _isScanning ? 'Stop Scanner' : 'Start Scanner',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isScanning
                                    ? AppTheme.errorColor
                                    : AppTheme.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.borderRadius,
                                  ),
                                ),
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
            const SizedBox(height: 24),

            // Enhanced Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Make sure the barcode is clearly visible and well-lit. The scanner will automatically detect and process the code.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Barcode scanned: ${barcode.rawValue}')),
          ],
        ),
        backgroundColor: AppTheme.statusAvailable,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
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
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add to Firestore
      await firestoreService.addProjector(projector);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Projector "${projector.projectorName}" added successfully!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.statusAvailable,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
          ),
        );

        // Navigate back with success result
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Error adding projector: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
          ),
        );
      }
    }
  }
}
