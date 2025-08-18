import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';
import '../../../../shared/models/lecturer.dart';

/// Enhanced screen for issuing projectors to lecturers
class IssueProjectorScreen extends ConsumerStatefulWidget {
  final Projector projector;

  const IssueProjectorScreen({super.key, required this.projector});

  @override
  ConsumerState<IssueProjectorScreen> createState() =>
      _IssueProjectorScreenState();
}

class _IssueProjectorScreenState extends ConsumerState<IssueProjectorScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadAllLecturers();
    _loadRecentLecturers();
    _validateProjectorStatus();
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
    if (widget.projector.status != AppConstants.statusAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Warning: Projector "${widget.projector.serialNumber}" is currently ${widget.projector.status.toLowerCase()}',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.warningColor ?? Colors.orange,
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
            _buildInfoRow('Serial Number', widget.projector.serialNumber),
            _buildInfoRow('Current Status', widget.projector.status),
            if (widget.projector.lastIssuedTo != null)
              _buildInfoRow('Last Issued To', widget.projector.lastIssuedTo!),
            if (widget.projector.lastIssuedDate != null)
              _buildInfoRow('Last Issue Date', _formatDate(widget.projector.lastIssuedDate!)),
            if (widget.projector.lastReturnDate != null)
              _buildInfoRow('Last Return Date', _formatDate(widget.projector.lastReturnDate!)),
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
          (lecturer.phoneNumber?.toLowerCase().contains(searchLower) ?? false) ||
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
        (l) => l.email.toLowerCase() == _newLecturerEmailController.text.trim().toLowerCase(),
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
    if (widget.projector.status != AppConstants.statusAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Projector is currently ${widget.projector.status.toLowerCase()}'),
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
        projectorId: widget.projector.id,
        lecturerId: _selectedLecturer!.id,
        projectorSerialNumber: widget.projector.serialNumber,
        lecturerName: _selectedLecturer!.name,
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
                    'Projector "${widget.projector.serialNumber}" issued to ${_selectedLecturer!.name} successfully!',
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
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
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

          // Quick Actions Overlay
          if (_showQuickActions) _buildQuickActionsOverlay(),
        ],
      ),
    );
  }

  /// Build enhanced header
  Widget _buildEnhancedHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.send,
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
                'Issue Projector',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Assign projector to a lecturer',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build projector information section
  Widget _buildProjectorInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 12),
              Text(
                'Projector Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Serial Number', widget.projector.serialNumber),
          const SizedBox(height: 8),
          _buildInfoRow('Current Status', widget.projector.status),
          if (widget.projector.lastIssuedTo != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Last Issued To', widget.projector.lastIssuedTo!),
          ],
          if (widget.projector.lastIssuedDate != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Last Issue Date', _formatDate(widget.projector.lastIssuedDate!)),
          ],
        ],
      ),
    );
  }

  /// Build lecturer selection section
  Widget _buildLecturerSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person, size: 16, color: AppTheme.accentColor),
            ),
            const SizedBox(width: 12),
            Text(
              'Select Lecturer',
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
          'Choose an existing lecturer or add a new one',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Toggle Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showAddLecturerForm ? _toggleAddLecturerForm : null,
                icon: const Icon(Icons.search),
                label: const Text('Search Existing'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _showAddLecturerForm
                      ? AppTheme.textSecondary
                      : AppTheme.accentColor,
                  side: BorderSide(
                    color: _showAddLecturerForm
                        ? AppTheme.textTertiary
                        : AppTheme.accentColor,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showAddLecturerForm ? null : _toggleAddLecturerForm,
                icon: const Icon(Icons.person_add),
                label: const Text('Add New'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _showAddLecturerForm
                      ? AppTheme.accentColor
                      : AppTheme.textSecondary,
                  side: BorderSide(
                    color: _showAddLecturerForm
                        ? AppTheme.accentColor
                        : AppTheme.textTertiary,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Conditional Content
        if (!_showAddLecturerForm) ...[
          // Search Field
          TextFormField(
            controller: _searchController,
            onChanged: _searchLecturers,
            decoration: InputDecoration(
              hintText: 'Search lecturers...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: _clearLecturerSelection,
                      icon: const Icon(Icons.clear),
                    )
                  : null,
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
                borderSide: BorderSide(color: AppTheme.accentColor, width: 2),
              ),
            ),
          ),
        ] else ...[
          // Add New Lecturer Form
          _buildAddLecturerForm(),
        ],

        // Search Results
        if (_isSearching && _searchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(
                color: AppTheme.textTertiary.withValues(alpha: 0.3),
              ),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final lecturer = _searchResults[index];
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
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lecturer.department),
                      if (lecturer.phoneNumber != null && lecturer.phoneNumber!.isNotEmpty)
                        Text(
                          lecturer.phoneNumber!,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  trailing: Text(
                    lecturer.email,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => _selectLecturer(lecturer),
                );
              },
            ),
          ),
        ],

        // Selected Lecturer Display
        if (_selectedLecturer != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(
                color: AppTheme.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.accentColor,
                  child: Text(
                    _selectedLecturer!.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
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
                        _selectedLecturer!.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _selectedLecturer!.department,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
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
                ),
              ],
            ),
          ),
        ],

        // No Results Message
        if (_isSearching && _searchResults.isEmpty && _searchQuery.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.textTertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            child: Row(
              children: [
                Icon(Icons.search_off, color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'No lecturers found matching "$_searchQuery"',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Build purpose and notes section
  Widget _buildPurposeAndNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Purpose Field
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.info, size: 16, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Text(
              'Purpose of Issue',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Brief description of why the projector is being issued',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _purposeController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'e.g., Lecture in Room 201, Department meeting...',
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: BorderSide(
                color: AppTheme.textTertiary.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Notes Field
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.note, size: 16, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Text(
              'Additional Notes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Optional: Add any special instructions or notes',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter any additional notes...',
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: BorderSide(
                color: AppTheme.textTertiary.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  /// Build action buttons
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
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
            onPressed: (_isLoading || _selectedLecturer == null)
                ? null
                : _issueProjector,
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedLecturer != null
                  ? AppTheme.accentColor
                  : AppTheme.textTertiary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _selectedLecturer != null
                        ? 'Issue to ${_selectedLecturer!.name}'
                        : 'Select Lecturer First',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
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
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
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
                    ..._recentLecturers.map((lecturer) => _buildQuickLecturerItem(lecturer)),
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
                      child: Icon(Icons.person_add, color: AppTheme.accentColor, size: 20),
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
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
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
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
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
