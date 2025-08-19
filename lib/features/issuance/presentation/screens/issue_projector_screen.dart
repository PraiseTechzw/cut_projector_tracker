import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';
import '../../../../shared/models/lecturer.dart';

/// Enhanced screen for issuing projectors to lecturers
class IssueProjectorScreen extends ConsumerStatefulWidget {
  final Projector? projector; // Make projector optional

  const IssueProjectorScreen({super.key, this.projector});

  @override
  ConsumerState<IssueProjectorScreen> createState() =>
      _IssueProjectorScreenState();
}

class _IssueProjectorScreenState extends ConsumerState<IssueProjectorScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  final _purposeController = TextEditingController();

  // New lecturer form controllers
  final _newLecturerFormKey = GlobalKey<FormState>();
  final _newLecturerNameController = TextEditingController();
  final _newLecturerDepartmentController = TextEditingController();
  final _newLecturerEmailController = TextEditingController();
  final _newLecturerPhoneNumberController = TextEditingController();
  final _newLecturerEmployeeIdController = TextEditingController();

  bool _isLoading = false;
  bool _isSearching = false;
  bool _showAddLecturerForm = false;
  bool _showQuickActions = false;
  String _searchQuery = '';
  Lecturer? _selectedLecturer;
  List<Lecturer> _searchResults = [];
  List<Lecturer> _allLecturers = [];
  List<Lecturer> _recentLecturers = [];

  // Add projector selection state
  Projector? _selectedProjector;
  bool _isSelectingProjector = false; // New state variable

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _selectedProjector = widget.projector; // Use passed projector if available
    _setupAnimations();
    _loadAllLecturers();
    _loadRecentLecturers();
    if (_selectedProjector != null) {
      _validateProjectorStatus();
    }
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    _purposeController.dispose();
    _newLecturerNameController.dispose();
    _newLecturerDepartmentController.dispose();
    _newLecturerEmailController.dispose();
    _newLecturerPhoneNumberController.dispose();
    _newLecturerEmployeeIdController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// Load all lecturers for search
  Future<void> _loadAllLecturers() async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final lecturersStream = firestoreService.getLecturers();
      final lecturers = await lecturersStream.first;
      setState(() {
        _allLecturers = lecturers;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading lecturers: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Validate projector status before allowing issue
  void _validateProjectorStatus() {
    if (_selectedProjector!.status != AppConstants.statusAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Warning: Projector "${_selectedProjector!.serialNumber}" is currently ${_selectedProjector!.status.toLowerCase()}',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.warningColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'View Details',
              textColor: Colors.white,
              onPressed: () {
                // Show projector details
                _showProjectorDetails();
              },
            ),
          ),
        );
      });
    }
  }

  /// Show projector details dialog
  void _showProjectorDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.qr_code, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text('Projector Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Serial Number', _selectedProjector!.serialNumber),
            _buildInfoRow('Current Status', _selectedProjector!.status),
            if (_selectedProjector!.modelName.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Model', _selectedProjector!.modelName),
            ],
            if (_selectedProjector!.projectorName.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Name', _selectedProjector!.projectorName),
            ],
            if (_selectedProjector!.lastIssuedTo != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Last Issued To',
                _selectedProjector!.lastIssuedTo!,
              ),
            ],
            if (_selectedProjector!.lastIssuedDate != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Last Issue Date',
                _formatDate(_selectedProjector!.lastIssuedDate!),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Load recent lecturers (last 5 used)
  Future<void> _loadRecentLecturers() async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final transactionsStream = firestoreService.getTransactions();
      final transactions = await transactionsStream.first;

      // Get unique lecturer names from recent transactions
      final recentLecturerNames = transactions
          .where((t) => t.status == AppConstants.transactionActive)
          .map((t) => t.lecturerName)
          .toSet()
          .take(5)
          .toList();

      // Find lecturer objects
      final recentLecturers = _allLecturers
          .where((l) => recentLecturerNames.contains(l.name))
          .toList();

      setState(() {
        _recentLecturers = recentLecturers;
      });
    } catch (e) {
      // Ignore errors for recent lecturers
    }
  }

  /// Scan or select projector
  Future<void> _selectProjector() async {
    final result = await context.push(
      '/scan-projector',
      extra: {'purpose': 'issue'},
    );
    if (result != null && result is Projector) {
      setState(() {
        _selectedProjector = result;
        _isSelectingProjector = false;
      });
      _validateProjectorStatus();
    }
  }

  /// Show manual projector entry bottom sheet
  void _showManualProjectorEntry() {
    final manualEntryController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
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
                          'Manual Projector Entry',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          'Enter projector serial number manually',
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

            // Input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: manualEntryController,
                decoration: InputDecoration(
                  labelText: 'Projector Serial Number',
                  hintText: 'Enter the projector serial number...',
                  prefixIcon: const Icon(Icons.qr_code),
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
                onSubmitted: (value) => _searchProjectorBySerial(value),
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
                      onPressed: () =>
                          _searchProjectorBySerial(manualEntryController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text('Search Projector'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Search projector by serial number
  Future<void> _searchProjectorBySerial(String serialNumber) async {
    if (serialNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a serial number'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final projectorsStream = firestoreService.getProjectors();
      final projectors = await projectorsStream.first;

      final projector = projectors.firstWhere(
        (p) =>
            p.serialNumber.toLowerCase() == serialNumber.trim().toLowerCase(),
        orElse: () => Projector(
          id: '',
          serialNumber: '',
          modelName: '',
          projectorName: '',
          status: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (projector.id.isNotEmpty) {
        Navigator.of(context).pop(); // Close bottom sheet

        setState(() {
          _selectedProjector = projector;
        });

        _validateProjectorStatus();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Projector ${projector.serialNumber} found!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Projector with serial number "$serialNumber" not found',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching for projector: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  /// Clear projector selection
  void _clearProjectorSelection() {
    setState(() {
      _selectedProjector = null;
      _selectedLecturer = null;
      _notesController.clear();
      _purposeController.clear();
    });
  }

  /// Search lecturers with enhanced logic
  void _searchLecturers(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedLecturer = null;
      });
      return;
    }

    // Enhanced search implementation
    final results = _allLecturers.where((lecturer) {
      final searchLower = query.toLowerCase();
      return lecturer.name.toLowerCase().contains(searchLower) ||
          lecturer.department.toLowerCase().contains(searchLower) ||
          lecturer.email.toLowerCase().contains(searchLower) ||
          (lecturer.phoneNumber?.toLowerCase().contains(searchLower) ??
              false) ||
          (lecturer.employeeId?.toLowerCase().contains(searchLower) ?? false);
    }).toList();

    // Sort by relevance (exact matches first)
    results.sort((a, b) {
      final aNameLower = a.name.toLowerCase();
      final bNameLower = b.name.toLowerCase();
      final queryLower = query.toLowerCase();

      final aStartsWith = aNameLower.startsWith(queryLower);
      final bStartsWith = bNameLower.startsWith(queryLower);

      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;
      return aNameLower.compareTo(bNameLower);
    });

    setState(() {
      _searchResults = results.take(10).toList(); // Limit to 10 results
    });
  }

  /// Select a lecturer
  void _selectLecturer(Lecturer lecturer) {
    setState(() {
      _selectedLecturer = lecturer;
      _searchQuery = lecturer.displayName;
      _searchResults = [];
      _isSearching = false;
    });

    // Add to recent lecturers if not already there
    if (!_recentLecturers.any((l) => l.id == lecturer.id)) {
      setState(() {
        _recentLecturers = [lecturer, ..._recentLecturers.take(4)];
      });
    }
  }

  /// Clear lecturer selection
  void _clearLecturerSelection() {
    setState(() {
      _selectedLecturer = null;
      _searchQuery = '';
      _searchResults = [];
      _isSearching = false;
    });
    _searchController.clear();
  }

  /// Toggle add lecturer form
  void _toggleAddLecturerForm() {
    setState(() {
      _showAddLecturerForm = !_showAddLecturerForm;
      if (_showAddLecturerForm) {
        _clearLecturerSelection();
      }
    });
  }

  /// Toggle quick actions
  void _toggleQuickActions() {
    setState(() {
      _showQuickActions = !_showQuickActions;
    });
  }

  /// Quick select lecturer
  void _quickSelectLecturer(Lecturer lecturer) {
    _selectLecturer(lecturer);
    setState(() {
      _showQuickActions = false;
    });
  }

  /// Add new lecturer with enhanced validation
  Future<void> _addNewLecturer() async {
    if (!_newLecturerFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Check if email already exists
      final existingLecturer = _allLecturers.firstWhere(
        (l) =>
            l.email.toLowerCase() ==
            _newLecturerEmailController.text.trim().toLowerCase(),
        orElse: () => Lecturer(
          id: '',
          name: '',
          department: '',
          email: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (existingLecturer.id.isNotEmpty) {
        throw 'A lecturer with this email already exists';
      }

      // Create new lecturer
      final now = DateTime.now();
      final newLecturer = Lecturer(
        id: '', // Will be generated by Firestore
        name: _newLecturerNameController.text.trim(),
        department: _newLecturerDepartmentController.text.trim(),
        email: _newLecturerEmailController.text.trim(),
        phoneNumber: _newLecturerPhoneNumberController.text.trim().isEmpty
            ? null
            : _newLecturerPhoneNumberController.text.trim(),
        employeeId: _newLecturerEmployeeIdController.text.trim().isEmpty
            ? null
            : _newLecturerEmployeeIdController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      // Add lecturer to database
      final lecturerId = await firestoreService.addLecturer(newLecturer);

      // Create lecturer with generated ID
      final createdLecturer = newLecturer.copyWith(id: lecturerId);

      if (mounted) {
        // Show success message with confetti
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Lecturer "${createdLecturer.name}" added successfully!',
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

        // Select the newly created lecturer
        setState(() {
          _selectedLecturer = createdLecturer;
          _showAddLecturerForm = false;
          _searchQuery = createdLecturer.displayName;
          _recentLecturers = [createdLecturer, ..._recentLecturers.take(4)];
        });

        // Clear form
        _newLecturerNameController.clear();
        _newLecturerDepartmentController.clear();
        _newLecturerEmailController.clear();
        _newLecturerPhoneNumberController.clear();
        _newLecturerEmployeeIdController.clear();

        // Refresh lecturers list
        _loadAllLecturers();
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
                Expanded(child: Text('Error adding lecturer: ${e.toString()}')),
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

  /// Issue projector with enhanced validation
  Future<void> _issueProjector() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLecturer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a lecturer'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Check if projector is available
    if (_selectedProjector!.status != AppConstants.statusAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Projector is currently ${_selectedProjector!.status.toLowerCase()}',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Issue the projector
      await firestoreService.issueProjector(
        projectorId: _selectedProjector!.id,
        lecturerId: _selectedLecturer!.id,
        projectorSerialNumber: _selectedProjector!.serialNumber,
        lecturerName: _selectedLecturer!.name,
        purpose: _purposeController.text.trim().isNotEmpty
            ? _purposeController.text.trim()
            : 'General use',
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        // Show success message with confetti
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Projector "${_selectedProjector!.serialNumber}" issued to ${_selectedLecturer!.name} successfully!',
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

        // Navigate back with success
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
                  child: Text('Error issuing projector: ${e.toString()}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Issue Projector'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: _toggleQuickActions,
            icon: Icon(_showQuickActions ? Icons.close : Icons.flash_on),
            tooltip: 'Quick Actions',
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                  AppTheme.backgroundColor,
                ],
              ),
            ),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
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
                          // Enhanced Header
                          _buildEnhancedHeader(),
                          const SizedBox(height: 24),

                          // Projector Information Section
                          _buildProjectorInfoSection(),
                          const SizedBox(height: 24),

                          // Lecturer Selection Section
                          _buildLecturerSelectionSection(),
                          const SizedBox(height: 24),

                          // Purpose and Notes Section
                          _buildPurposeAndNotesSection(),
                          const SizedBox(height: 32),

                          // Action Buttons
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Quick Actions Overlay
          if (_showQuickActions) _buildQuickActionsOverlay(),
        ],
      ),
    );
  }

  /// Build enhanced header
  Widget _buildEnhancedHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.secondaryColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              Icons.send_rounded,
              color: AppTheme.primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Issue Projector',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedProjector != null
                      ? 'Assigning ${_selectedProjector!.serialNumber} to a lecturer'
                      : 'Select a projector and assign it to a lecturer',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (_selectedProjector != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Projector Selected',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedProjector!.modelName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppTheme.secondaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedProjector!.modelName,
                            style: TextStyle(
                              color: AppTheme.secondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build projector information section
  Widget _buildProjectorInfoSection() {
    if (_selectedProjector == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner,
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
                        'Projector Selection',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'No projector selected yet',
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.textTertiary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please scan or select a projector to continue with the issuance process.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectProjector,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Projector'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadius,
                    ),
                  ),
                  elevation: 4,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.qr_code,
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
                      'Projector Information',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Ready for issuance',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      _selectedProjector!.status == AppConstants.statusAvailable
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        _selectedProjector!.status ==
                            AppConstants.statusAvailable
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _selectedProjector!.status == AppConstants.statusAvailable
                          ? Icons.check_circle
                          : Icons.warning,
                      size: 16,
                      color:
                          _selectedProjector!.status ==
                              AppConstants.statusAvailable
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedProjector!.status,
                      style: TextStyle(
                        color:
                            _selectedProjector!.status ==
                                AppConstants.statusAvailable
                            ? Colors.green
                            : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.textTertiary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  'Serial Number',
                  _selectedProjector!.serialNumber,
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Current Status', _selectedProjector!.status),
                if (_selectedProjector!.modelName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow('Model', _selectedProjector!.modelName),
                ],
                if (_selectedProjector!.projectorName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow('Name', _selectedProjector!.projectorName),
                ],
                if (_selectedProjector!.lastIssuedTo != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    'Last Issued To',
                    _selectedProjector!.lastIssuedTo!,
                  ),
                ],
                if (_selectedProjector!.lastIssuedDate != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    'Last Issue Date',
                    _formatDate(_selectedProjector!.lastIssuedDate!),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectProjector,
                  icon: const Icon(Icons.change_circle),
                  label: const Text('Change Projector'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadius,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearProjectorSelection,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Selection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.textTertiary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadius,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build lecturer selection section
  Widget _buildLecturerSelectionSection() {
    if (_selectedProjector == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.textTertiary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.textTertiary.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 24,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Lecturer',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Waiting for projector selection',
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.textTertiary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please select a projector first to continue with lecturer selection.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.4,
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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person,
                  size: 24,
                  color: AppTheme.accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Lecturer',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Choose an existing lecturer or add a new one',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedLecturer != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'Lecturer Selected',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Toggle Buttons
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.textTertiary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: !_showAddLecturerForm
                          ? AppTheme.accentColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showAddLecturerForm
                            ? _toggleAddLecturerForm
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                color: !_showAddLecturerForm
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Search Existing',
                                style: TextStyle(
                                  color: !_showAddLecturerForm
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _showAddLecturerForm
                          ? AppTheme.accentColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showAddLecturerForm
                            ? null
                            : _toggleAddLecturerForm,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_add,
                                color: _showAddLecturerForm
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Add New',
                                style: TextStyle(
                                  color: _showAddLecturerForm
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Conditional Content
          if (!_showAddLecturerForm) ...[
            // Search Field
            Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.textTertiary.withValues(alpha: 0.2),
                ),
              ),
              child: TextFormField(
                controller: _searchController,
                onChanged: _searchLecturers,
                decoration: InputDecoration(
                  hintText: 'Search lecturers by name, department, or email...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: _clearLecturerSelection,
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Add New Lecturer Form
            _buildAddLecturerForm(),
          ],

          // Search Results
          if (_isSearching && _searchResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.textTertiary.withValues(alpha: 0.2),
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final lecturer = _searchResults[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectLecturer(lecturer),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.accentColor.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                lecturer.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.accentColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lecturer.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lecturer.department,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (lecturer.phoneNumber != null &&
                                      lecturer.phoneNumber!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      lecturer.phoneNumber!,
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  lecturer.email,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Tap to select',
                                    style: TextStyle(
                                      color: AppTheme.accentColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
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
                },
              ),
            ),
          ],

          // Selected Lecturer Display
          if (_selectedLecturer != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.accentColor,
                    child: Text(
                      _selectedLecturer!.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedLecturer!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedLecturer!.department,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedLecturer!.email,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (_selectedLecturer!.phoneNumber != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _selectedLecturer!.phoneNumber!,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _clearLecturerSelection,
                    icon: const Icon(Icons.close),
                    color: AppTheme.textSecondary,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.8),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // No Results Message
          if (_isSearching &&
              _searchResults.isEmpty &&
              _searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.textTertiary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_off,
                    color: AppTheme.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No lecturers found',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No lecturers found matching "$_searchQuery". Try a different search term or add a new lecturer.',
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
          ],
        ],
      ),
    );
  }

  /// Build purpose and notes section
  Widget _buildPurposeAndNotesSection() {
    if (_selectedProjector == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.textTertiary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.textTertiary.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    size: 24,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purpose & Notes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Waiting for projector selection',
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.textTertiary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please select a projector first to continue.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.4,
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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.info, size: 24, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purpose & Notes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Provide details about the issuance',
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
          const SizedBox(height: 20),

          // Purpose Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.label_important,
                    color: AppTheme.primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Purpose of Issue',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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
                'Brief description of why the projector is being issued',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.textTertiary.withValues(alpha: 0.2),
                  ),
                ),
                child: TextFormField(
                  controller: _purposeController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText:
                        'e.g., Lecture in Room 201, Department meeting, Training session...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Notes Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.note, color: AppTheme.primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Additional Notes',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Optional: Add any special instructions or notes',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.textTertiary.withValues(alpha: 0.2),
                  ),
                ),
                child: TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'Enter any additional notes, special instructions, or requirements...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons() {
    if (_selectedProjector == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.play_arrow,
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
                        'Ready to Start',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Begin the issuance process',
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectProjector,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Start by Scanning a Projector'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadius,
                    ),
                  ),
                  elevation: 6,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _selectedLecturer != null
            ? Colors.green.withValues(alpha: 0.05)
            : AppTheme.textTertiary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedLecturer != null
              ? Colors.green.withValues(alpha: 0.2)
              : AppTheme.textTertiary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedLecturer != null
                      ? Colors.green.withValues(alpha: 0.15)
                      : AppTheme.textTertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _selectedLecturer != null
                      ? Icons.check_circle
                      : Icons.pending,
                  color: _selectedLecturer != null
                      ? Colors.green
                      : AppTheme.textTertiary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedLecturer != null
                          ? 'Ready to Issue'
                          : 'Almost Ready',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _selectedLecturer != null
                            ? Colors.green
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _selectedLecturer != null
                          ? 'All requirements are met'
                          : 'Please select a lecturer to continue',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedLecturer != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'Ready',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadius,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton(
                    onPressed: (_isLoading || _selectedLecturer == null)
                        ? null
                        : _issueProjector,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedLecturer != null
                          ? Colors.green
                          : AppTheme.textTertiary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                      ),
                      elevation: _selectedLecturer != null ? 6 : 2,
                      shadowColor: _selectedLecturer != null
                          ? Colors.green.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedLecturer != null
                                    ? Icons.send
                                    : Icons.pending,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedLecturer != null
                                    ? 'Issue to ${_selectedLecturer!.name}'
                                    : 'Select Lecturer First',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedLecturer != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Projector will be issued to ${_selectedLecturer!.name} from ${_selectedLecturer!.department}',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build quick actions overlay
  Widget _buildQuickActionsOverlay() {
    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.flash_on, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Recent Lecturers
            if (_recentLecturers.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Lecturers',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._recentLecturers.map(
                      (lecturer) => _buildQuickLecturerItem(lecturer),
                    ),
                  ],
                ),
              ),
            ],

            // Quick Add
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Add',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person_add,
                        color: AppTheme.accentColor,
                        size: 20,
                      ),
                    ),
                    title: const Text('Add New Lecturer'),
                    subtitle: const Text('Create lecturer account'),
                    onTap: () {
                      setState(() {
                        _showQuickActions = false;
                        _showAddLecturerForm = true;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build quick lecturer item
  Widget _buildQuickLecturerItem(Lecturer lecturer) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
        child: Text(
          lecturer.name[0].toUpperCase(),
          style: TextStyle(
            color: AppTheme.accentColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        lecturer.name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        lecturer.department,
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      onTap: () => _quickSelectLecturer(lecturer),
    );
  }

  /// Build add lecturer form
  Widget _buildAddLecturerForm() {
    return Form(
      key: _newLecturerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Lecturer',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Name Field
          TextFormField(
            controller: _newLecturerNameController,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              hintText: 'Enter lecturer\'s full name',
              prefixIcon: const Icon(Icons.person),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Department Field
          TextFormField(
            controller: _newLecturerDepartmentController,
            decoration: InputDecoration(
              labelText: 'Department *',
              hintText: 'Enter department name',
              prefixIcon: const Icon(Icons.business),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Department is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email Field
          TextFormField(
            controller: _newLecturerEmailController,
            decoration: InputDecoration(
              labelText: 'Email *',
              hintText: 'Enter email address',
              prefixIcon: const Icon(Icons.email),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Phone Number Field (Optional)
          TextFormField(
            controller: _newLecturerPhoneNumberController,
            decoration: InputDecoration(
              labelText: 'Phone Number (Optional)',
              hintText: 'Enter phone number',
              prefixIcon: const Icon(Icons.phone),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Employee ID Field (Optional)
          TextFormField(
            controller: _newLecturerEmployeeIdController,
            decoration: InputDecoration(
              labelText: 'Employee ID (Optional)',
              hintText: 'Enter employee ID if available',
              prefixIcon: const Icon(Icons.badge),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Add Lecturer Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _addNewLecturer,
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.person_add),
              label: Text(_isLoading ? 'Adding...' : 'Add Lecturer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build info row
  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
