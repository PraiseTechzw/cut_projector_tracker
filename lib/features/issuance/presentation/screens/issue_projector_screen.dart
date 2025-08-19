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
    List<Projector> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildManualEntryHeader(),
                _buildAvailableProjectorsList(setState),
                _buildSearchInput(
                  manualEntryController,
                  setState,
                  searchResults,
                  isSearching,
                ),
                _buildSearchResults(
                  searchResults,
                  isSearching,
                  manualEntryController,
                  setState,
                ),
                _buildHelpfulTip(),
                _buildModalActionButtons(
                  manualEntryController,
                  setState,
                  searchResults,
                  isSearching,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build the header section for manual entry
  Widget _buildManualEntryHeader() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.keyboard,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manual Projector Entry',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Search and select projectors from database',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: AppTheme.textSecondary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.backgroundColor,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the search input field
  Widget _buildSearchInput(
    TextEditingController controller,
    StateSetter setState,
    List<Projector> searchResults,
    bool isSearching,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Projectors',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search by serial number, model, or name',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Search Projectors',
                hintText: 'Enter serial number, model, or name...',
                prefixIcon: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.search,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: AppTheme.errorColor,
                            size: 20,
                          ),
                          onPressed: () {
                            controller.clear();
                            setState(() {
                              searchResults.clear();
                              isSearching = false;
                            });
                          },
                        ),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                labelStyle: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                hintStyle: TextStyle(
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) {
                setState(() {
                  if (value.trim().isEmpty) {
                    searchResults.clear();
                    isSearching = false;
                  } else {
                    _searchProjectorsInDatabase(
                      value,
                      setState,
                      searchResults,
                      isSearching,
                    );
                  }
                });
              },
              onFieldSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _searchProjectorsInDatabase(
                    value,
                    setState,
                    searchResults,
                    isSearching,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build the search results section
  Widget _buildSearchResults(
    List<Projector> searchResults,
    bool isSearching,
    TextEditingController controller,
    StateSetter setState,
  ) {
    if (searchResults.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Search Results (${searchResults.length})',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final projector = searchResults[index];
                  return _buildProjectorResultItem(projector, setState);
                },
              ),
            ),
          ],
        ),
      );
    } else if (isSearching) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Searching projectors...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    } else if (controller.text.trim().isNotEmpty && searchResults.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.textTertiary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.textTertiary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search_off, color: AppTheme.textSecondary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No projectors found',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No projectors found matching "${controller.text.trim()}". Try a different search term.',
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
      );
    }
    return const SizedBox.shrink();
  }

  /// Build individual projector result item
  Widget _buildProjectorResultItem(Projector projector, StateSetter setState) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          setState(() {
            _selectedProjector = projector;
          });
          _validateProjectorStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Projector ${projector.serialNumber} selected!'),
              backgroundColor: Colors.green,
            ),
          );
        },
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                      projector.serialNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                        fontFamily: 'monospace',
                        fontSize: 16,
                      ),
                    ),
                    if (projector.modelName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        projector.modelName,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (projector.projectorName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        projector.projectorName,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        projector.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(
                          projector.status,
                        ).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      projector.status,
                      style: TextStyle(
                        color: _getStatusColor(projector.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.1),
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
  }

  /// Build available projectors list
  Widget _buildAvailableProjectorsList(StateSetter setState) {
    return FutureBuilder<List<Projector>>(
      future: _getAvailableProjectors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final availableProjectors = snapshot.data!;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Available Projectors (${availableProjectors.length})',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableProjectors.length,
                  itemBuilder: (context, index) {
                    final projector = availableProjectors[index];
                    return _buildAvailableProjectorItem(projector, setState);
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// Build individual available projector item
  Widget _buildAvailableProjectorItem(
    Projector projector,
    StateSetter setState,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          setState(() {
            _selectedProjector = projector;
          });
          _validateProjectorStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Projector ${projector.serialNumber} selected!'),
              backgroundColor: Colors.green,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.qr_code,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      projector.serialNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                    if (projector.modelName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        projector.modelName,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tap to select',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get available projectors from database
  Future<List<Projector>> _getAvailableProjectors() async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final projectorsStream = firestoreService.getProjectors();
      final allProjectors = await projectorsStream.first;

      return allProjectors
          .where((p) => p.status == AppConstants.statusAvailable)
          .take(10) // Limit to 10 for performance
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Build helpful tip section
  Widget _buildHelpfulTip() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tip: Search by serial number, model name, or projector name. Results update as you type.',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build modal action buttons
  Widget _buildModalActionButtons(
    TextEditingController controller,
    StateSetter setState,
    List<Projector> searchResults,
    bool isSearching,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: AppTheme.textTertiary, width: 1.5),
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
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  _searchProjectorsInDatabase(
                    controller.text.trim(),
                    setState,
                    searchResults,
                    isSearching,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text('Search Projectors'),
            ),
          ),
        ],
      ),
    );
  }

  /// Search projectors in database with enhanced search
  Future<void> _searchProjectorsInDatabase(
    String query,
    StateSetter setModalState,
    List<Projector> searchResults,
    bool isSearching,
  ) async {
    if (query.trim().isEmpty) {
      setModalState(() {
        searchResults.clear();
        isSearching = false;
      });
      return;
    }

    setModalState(() {
      isSearching = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final projectorsStream = firestoreService.getProjectors();
      final allProjectors = await projectorsStream.first;

      // Enhanced search logic
      final results = allProjectors.where((projector) {
        final searchLower = query.toLowerCase();
        return projector.serialNumber.toLowerCase().contains(searchLower) ||
            projector.modelName.toLowerCase().contains(searchLower) ||
            projector.projectorName.toLowerCase().contains(searchLower) ||
            (projector.location?.toLowerCase().contains(searchLower) ?? false);
      }).toList();

      // Sort by relevance (exact matches first)
      results.sort((a, b) {
        final aSerialLower = a.serialNumber.toLowerCase();
        final bSerialLower = b.serialNumber.toLowerCase();
        final queryLower = query.toLowerCase();

        final aStartsWith = aSerialLower.startsWith(queryLower);
        final bStartsWith = bSerialLower.startsWith(queryLower);

        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;
        return aSerialLower.compareTo(bSerialLower);
      });

      setModalState(() {
        searchResults.clear();
        searchResults.addAll(results.take(10)); // Limit to 10 results
        isSearching = false;
      });
    } catch (e) {
      setModalState(() {
        searchResults.clear();
        isSearching = false;
      });
    }
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

  /// Issue projector with enhanced validation and confirmation
  Future<void> _issueProjector() async {
    // Step 1: Basic form validation
    if (!_formKey.currentState!.validate()) {
      _showValidationError('Please fill in all required fields correctly.');
      return;
    }

    // Step 2: Validate lecturer selection
    if (_selectedLecturer == null) {
      _showValidationError(
        'Please select a lecturer to issue the projector to.',
      );
      return;
    }

    // Step 3: Validate projector status
    if (_selectedProjector!.status != AppConstants.statusAvailable) {
      _showValidationError(
        'Projector "${_selectedProjector!.serialNumber}" is currently ${_selectedProjector!.status.toLowerCase()} and cannot be issued.',
      );
      return;
    }

    // Step 4: Validate purpose field (make it required)
    if (_purposeController.text.trim().isEmpty) {
      _showValidationError(
        'Please specify the purpose for issuing this projector.',
      );
      return;
    }

    // Step 5: Show confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) {
      return; // User cancelled
    }

    // Step 6: Final validation check (in case status changed)
    if (_selectedProjector!.status != AppConstants.statusAvailable) {
      _showValidationError(
        'Projector status has changed. Please refresh and try again.',
      );
      return;
    }

    // Step 7: Proceed with issuance
    setState(() {
      _isLoading = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Issue the projector with enhanced data
      await firestoreService.issueProjector(
        projectorId: _selectedProjector!.id,
        lecturerId: _selectedLecturer!.id,
        projectorSerialNumber: _selectedProjector!.serialNumber,
        lecturerName: _selectedLecturer!.name,
        purpose: _purposeController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        // Show enhanced success message
        _showSuccessMessage();

        // Navigate back with success after a brief delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _showErrorMessage('Error issuing projector: ${e.toString()}');
      }
    }
  }

  /// Show validation error with enhanced styling
  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Validation Error',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(message, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.warningColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        margin: const EdgeInsets.all(AppConstants.defaultPadding),
      ),
    );
  }

  /// Show enhanced confirmation bottom sheet before issuing
  Future<bool> _showConfirmationDialog() async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildConfirmationHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildConfirmationDescription(),
                          const SizedBox(height: 24),
                          _buildConfirmationDetails(),
                          const SizedBox(height: 24),
                          _buildConfirmationWarning(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  _buildConfirmationActions(),
                ],
              ),
            );
          },
        ) ??
        false;
  }

  /// Build confirmation header
  Widget _buildConfirmationHeader() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.confirmation_number,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirm Projector Issue',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review details before proceeding',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build confirmation description
  Widget _buildConfirmationDescription() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Please review the following details carefully before issuing the projector. This action cannot be undone.',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build confirmation details
  Widget _buildConfirmationDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Issue Details',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),

        // Projector details
        _buildEnhancedConfirmationItem(
          'Projector',
          _selectedProjector!.serialNumber,
          Icons.qr_code,
          AppTheme.primaryColor,
          subtitle: _selectedProjector!.modelName.isNotEmpty
              ? _selectedProjector!.modelName
              : null,
        ),
        const SizedBox(height: 16),

        // Lecturer details
        _buildEnhancedConfirmationItem(
          'Issuing To',
          _selectedLecturer!.name,
          Icons.person,
          AppTheme.accentColor,
          subtitle: _selectedLecturer!.department,
        ),
        const SizedBox(height: 16),

        // Purpose
        _buildEnhancedConfirmationItem(
          'Purpose',
          _purposeController.text.trim(),
          Icons.assignment,
          AppTheme.secondaryColor,
        ),

        // Notes if provided
        if (_notesController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildEnhancedConfirmationItem(
            'Additional Notes',
            _notesController.text.trim(),
            Icons.note,
            AppTheme.textSecondary,
          ),
        ],
      ],
    );
  }

  /// Build enhanced confirmation item
  Widget _buildEnhancedConfirmationItem(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build confirmation warning
  Widget _buildConfirmationWarning() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.warningColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Notice',
                  style: TextStyle(
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This action will mark the projector as "Issued" and update the inventory status. The projector will no longer be available for other users.',
                  style: TextStyle(
                    color: AppTheme.warningColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build confirmation actions
  Widget _buildConfirmationActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: AppTheme.textTertiary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
              ),
              child: const Text(
                'Confirm & Issue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build confirmation item for the dialog
  Widget _buildConfirmationItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Show enhanced success message
  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Projector Issued Successfully!',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedProjector!.serialNumber} → ${_selectedLecturer!.name}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppTheme.statusAvailable,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        margin: const EdgeInsets.all(AppConstants.defaultPadding),
      ),
    );
  }

  /// Show enhanced error message
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Issue Failed',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(message, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        margin: const EdgeInsets.all(AppConstants.defaultPadding),
      ),
    );
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
              vertical: AppConstants.defaultPadding * 0.5,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
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
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Enhanced Header
                          _buildEnhancedHeader(),
                          const SizedBox(height: 20),

                          // Step Indicator
                          _buildStepIndicator(),
                          const SizedBox(height: 20),

                          // Projector Information Section
                          _buildProjectorInfoSection(),
                          const SizedBox(height: 20),

                          // Lecturer Selection Section
                          _buildLecturerSelectionSection(),
                          const SizedBox(height: 20),

                          // Purpose and Notes Section
                          _buildPurposeAndNotesSection(),
                          const SizedBox(height: 24),

                          // Action Buttons
                          _buildMainActionButtons(),
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

  /// Check if screen is small for responsive layout
  bool get _isSmallScreen {
    return MediaQuery.of(context).size.height < 700;
  }

  /// Build step indicator showing progress
  Widget _buildStepIndicator() {
    // Use more compact layout on smaller screens
    if (_isSmallScreen) {
      return _buildCompactStepIndicator();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.track_changes, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 12),
              Text(
                'Issuance Progress',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Use horizontal scroll for step indicator on smaller screens
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Step 1: Projector Selection
                SizedBox(
                  width: 80,
                  child: _buildStepItem(
                    stepNumber: 1,
                    title: 'Projector',
                    subtitle: 'Select',
                    isCompleted: _selectedProjector != null,
                    isActive: _selectedProjector != null,
                    icon: Icons.qr_code,
                  ),
                ),
                _buildStepConnector(_selectedProjector != null),

                // Step 2: Lecturer Selection
                SizedBox(
                  width: 80,
                  child: _buildStepItem(
                    stepNumber: 2,
                    title: 'Lecturer',
                    subtitle: 'Choose',
                    isCompleted: _selectedLecturer != null,
                    isActive: _selectedLecturer != null,
                    icon: Icons.person,
                  ),
                ),
                _buildStepConnector(_selectedLecturer != null),

                // Step 3: Purpose & Notes
                SizedBox(
                  width: 80,
                  child: _buildStepItem(
                    stepNumber: 3,
                    title: 'Details',
                    subtitle: 'Purpose',
                    isCompleted: _purposeController.text.trim().isNotEmpty,
                    isActive: _purposeController.text.trim().isNotEmpty,
                    icon: Icons.assignment,
                  ),
                ),
                _buildStepConnector(_purposeController.text.trim().isNotEmpty),

                // Step 4: Confirmation
                SizedBox(
                  width: 80,
                  child: _buildStepItem(
                    stepNumber: 4,
                    title: 'Confirm',
                    subtitle: 'Review',
                    isCompleted: false,
                    isActive:
                        _selectedProjector != null &&
                        _selectedLecturer != null &&
                        _purposeController.text.trim().isNotEmpty,
                    icon: Icons.check_circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual step item
  Widget _buildStepItem({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    required IconData icon,
  }) {
    final color = isCompleted || isActive
        ? AppTheme.primaryColor
        : AppTheme.textTertiary;

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppTheme.primaryColor
                : isActive
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : AppTheme.textTertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color, width: isActive ? 2 : 1),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, color: Colors.white, size: 18)
                : Icon(icon, color: color, size: 18),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Build compact step indicator for small screens
  Widget _buildCompactStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Progress',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Row(
            children: [
              _buildCompactStepDot(
                _selectedProjector != null,
                AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              _buildCompactStepDot(
                _selectedLecturer != null,
                AppTheme.accentColor,
              ),
              const SizedBox(width: 8),
              _buildCompactStepDot(
                _purposeController.text.trim().isNotEmpty,
                AppTheme.secondaryColor,
              ),
              const SizedBox(width: 8),
              _buildCompactStepDot(
                _selectedProjector != null &&
                    _selectedLecturer != null &&
                    _purposeController.text.trim().isNotEmpty,
                AppTheme.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build compact step dot
  Widget _buildCompactStepDot(bool isCompleted, Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isCompleted ? color : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: isCompleted ? 0 : 1),
      ),
    );
  }

  /// Build step connector
  Widget _buildStepConnector(bool isCompleted) {
    return Container(
      width: 16,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppTheme.primaryColor
            : AppTheme.textTertiary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(1),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Please scan or manually enter a projector to continue with the issuance process.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code,
                        color: AppTheme.primaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Scan: Use the camera to scan QR codes or barcodes',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.keyboard,
                        color: AppTheme.accentColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Manual: Type the serial number directly',
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
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
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showManualProjectorEntry,
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Manual Entry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildEnhancedInfoRow(
                  'Serial Number',
                  _selectedProjector!.serialNumber,
                  Icons.qr_code,
                  AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                _buildEnhancedInfoRow(
                  'Current Status',
                  _selectedProjector!.status,
                  Icons.info_outline,
                  _getStatusColor(_selectedProjector!.status),
                ),
                if (_selectedProjector!.modelName.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildEnhancedInfoRow(
                    'Model',
                    _selectedProjector!.modelName,
                    Icons.model_training,
                    AppTheme.secondaryColor,
                  ),
                ],
                if (_selectedProjector!.projectorName.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildEnhancedInfoRow(
                    'Name',
                    _selectedProjector!.projectorName,
                    Icons.label,
                    AppTheme.accentColor,
                  ),
                ],
                if (_selectedProjector!.location?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  _buildEnhancedInfoRow(
                    'Location',
                    _selectedProjector!.location!,
                    Icons.location_on,
                    AppTheme.textSecondary,
                  ),
                ],
                if (_selectedProjector!.lastIssuedTo != null) ...[
                  const SizedBox(height: 16),
                  _buildEnhancedInfoRow(
                    'Last Issued To',
                    _selectedProjector!.lastIssuedTo!,
                    Icons.person,
                    AppTheme.statusIssued,
                  ),
                ],
                if (_selectedProjector!.lastIssuedDate != null) ...[
                  const SizedBox(height: 16),
                  _buildEnhancedInfoRow(
                    'Last Issue Date',
                    _formatDate(_selectedProjector!.lastIssuedDate!),
                    Icons.schedule,
                    AppTheme.textSecondary,
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
                  label: const Text('Scan Different'),
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
                  onPressed: _showManualProjectorEntry,
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Manual Entry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentColor,
                    side: BorderSide(color: AppTheme.accentColor, width: 1.5),
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
                  label: const Text('Clear'),
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
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        _purposeController.text.trim().isEmpty &&
                            _purposeController.text.isNotEmpty
                        ? AppTheme.errorColor.withValues(alpha: 0.5)
                        : AppTheme.textTertiary.withValues(alpha: 0.2),
                  ),
                ),
                child: TextFormField(
                  controller: _purposeController,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Purpose is required';
                    }
                    if (value.trim().length < 10) {
                      return 'Purpose must be at least 10 characters';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      // Trigger rebuild to update border color
                    });
                  },
                  decoration: InputDecoration(
                    hintText:
                        'e.g., Lecture in Room 201, Department meeting, Training session...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    errorStyle: TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                    ),
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
                width: double.infinity,
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

  /// Build main action buttons
  Widget _buildMainActionButtons() {
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
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectProjector,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Projector'),
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
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showManualProjectorEntry,
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Manual Entry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 20),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectedLecturer != null
                                    ? Icons.send
                                    : Icons.pending,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _selectedLecturer != null
                                      ? 'Issue to ${_selectedLecturer!.name.split(' ').first}'
                                      : 'Select Lecturer',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
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

            // Quick Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
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
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.keyboard,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    title: const Text('Manual Projector Entry'),
                    subtitle: const Text('Enter serial number manually'),
                    onTap: () {
                      setState(() {
                        _showQuickActions = false;
                      });
                      _showManualProjectorEntry();
                    },
                  ),
                  const SizedBox(height: 8),
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

  /// Build enhanced info row with icons and colors
  Widget _buildEnhancedInfoRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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

  /// Get status color for projectors
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available':
        return AppTheme.statusAvailable;
      case 'Issued':
        return AppTheme.statusIssued;
      case 'Maintenance':
        return AppTheme.statusMaintenance;
      default:
        return AppTheme.textTertiary;
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
