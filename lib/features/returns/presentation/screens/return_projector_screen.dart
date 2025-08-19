import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';
import '../../../../shared/models/transaction.dart';

/// Screen for returning projectors from lecturers
class ReturnProjectorScreen extends ConsumerStatefulWidget {
  final Projector projector;
  final ProjectorTransaction? activeTransaction;

  const ReturnProjectorScreen({
    super.key,
    required this.projector,
    this.activeTransaction,
  });

  @override
  ConsumerState<ReturnProjectorScreen> createState() =>
      _ReturnProjectorScreenState();
}

class _ReturnProjectorScreenState extends ConsumerState<ReturnProjectorScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _returnNotesController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isSearching = false;

  ProjectorTransaction? _currentTransaction;
  Projector? _selectedProjector;
  List<Projector> _issuedProjectors = [];
  List<Projector> _filteredProjectors = [];

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Smart validation
  bool _isEligibleForReturn = false;
  String? _validationMessage;
  List<String> _returnNoteSuggestions = [];

  @override
  void initState() {
    super.initState();
    _currentTransaction = widget.activeTransaction;
    _selectedProjector = widget.projector;
    _setupAnimations();
    _loadIssuedProjectors();
    _validateProjector();
    _generateSuggestions();
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

    _fadeController.forward();
    _slideController.forward();
  }

  /// Validate projector eligibility for return
  void _validateProjector() {
    if (widget.projector.status != AppConstants.statusIssued) {
      _isEligibleForReturn = false;
      _validationMessage = 'This projector is not currently issued';
      return;
    }

    if (_currentTransaction == null) {
      _isEligibleForReturn = false;
      _validationMessage = 'No active transaction found';
      return;
    }

    // Check for long-term usage
    final daysIssued = DateTime.now()
        .difference(_currentTransaction!.dateIssued)
        .inDays;
    if (daysIssued > 30) {
      _isEligibleForReturn = false;
      _validationMessage =
          'Projector issued for over 30 days. Contact administrator.';
      return;
    }

    _isEligibleForReturn = true;
    _validationMessage = null;
  }

  /// Load issued projectors from Firestore
  Future<void> _loadIssuedProjectors() async {
    setState(() {
      _isSearching = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final projectorsStream = firestoreService.getProjectors();

      await for (final projectors in projectorsStream) {
        final issuedProjectors = projectors
            .where((projector) => projector.status == AppConstants.statusIssued)
            .toList();

        setState(() {
          _issuedProjectors = issuedProjectors;
          _filteredProjectors = issuedProjectors;
          _isSearching = false;
        });
        break; // Exit after first load
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading projectors: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Filter projectors based on search query
  void _filterProjectors(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProjectors = _issuedProjectors;
      });
    } else {
      final filtered = _issuedProjectors
          .where(
            (projector) =>
                projector.serialNumber.toLowerCase().contains(
                  query.toLowerCase(),
                ) ||
                (projector.projectorName.isNotEmpty &&
                    projector.projectorName.toLowerCase().contains(
                      query.toLowerCase(),
                    )) ||
                (projector.modelName.isNotEmpty &&
                    projector.modelName.toLowerCase().contains(
                      query.toLowerCase(),
                    )),
          )
          .toList();
      setState(() {
        _filteredProjectors = filtered;
      });
    }
  }

  /// Select a projector and load its transaction
  Future<void> _selectProjector(Projector projector) async {
    setState(() {
      _selectedProjector = projector;
      _isLoading = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final transactionsStream = firestoreService.getActiveTransactions();

      await for (final transactions in transactionsStream) {
        final activeTransaction = transactions
            .where((transaction) => transaction.projectorId == projector.id)
            .firstOrNull;

        if (activeTransaction != null) {
          setState(() {
            _currentTransaction = activeTransaction;
            _isLoading = false;
          });
          _validateProjector();
          _generateSuggestions();
          return;
        }
      }

      // No active transaction found
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No active transaction found for this projector',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transaction: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Generate intelligent return note suggestions
  void _generateSuggestions() {
    if (_currentTransaction == null) return;

    final daysIssued = DateTime.now()
        .difference(_currentTransaction!.dateIssued)
        .inDays;

    _returnNoteSuggestions = [
      'Projector in good condition',
      'No visible damage',
      'All accessories included',
      'Ready for next use',
    ];

    if (daysIssued > 7) {
      _returnNoteSuggestions.add(
        'Extended use - thorough inspection recommended',
      );
      _returnNoteSuggestions.add('Check for wear and tear');
    }

    if (daysIssued > 14) {
      _returnNoteSuggestions.add(
        'Long-term usage - maintenance may be required',
      );
      _returnNoteSuggestions.add('Inspect lens and cooling system');
    }
  }

  @override
  void dispose() {
    _returnNotesController.dispose();
    _searchController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// Return projector
  Future<void> _returnProjector() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Intelligent validation
    if (!_isEligibleForReturn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _validationMessage ?? 'Projector cannot be returned',
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_currentTransaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active transaction found for this projector'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Show confirmation for long-term returns
    final daysIssued = DateTime.now()
        .difference(_currentTransaction!.dateIssued)
        .inDays;
    if (daysIssued > 14) {
      final shouldProceed = await _showLongTermReturnConfirmation(daysIssued);
      if (!shouldProceed) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Return the projector using the existing method
      await firestoreService.returnProjector(
        transactionId: _currentTransaction!.id,
        projectorId: widget.projector.id,
        returnNotes: _returnNotesController.text.trim(),
      );

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
                    'Projector "${widget.projector.serialNumber}" returned successfully!',
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
                  child: Text('Error returning projector: ${e.toString()}'),
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

  /// Show confirmation dialog for long-term returns
  Future<bool> _showLongTermReturnConfirmation(int daysIssued) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text('Long-term Return'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This projector has been issued for $daysIssued days.',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please ensure thorough inspection and note any wear or damage.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Proceed with Return'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Return Projector'),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.secondaryColor,
                AppTheme.secondaryColor.withValues(alpha: 0.8),
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
                  AppTheme.secondaryColor.withValues(alpha: 0.05),
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

                        // Projector Selection Section
                        _buildProjectorSelectionSection(),
                        const SizedBox(height: 24),

                        // Transaction Information Section (only if projector selected)
                        if (_selectedProjector != null) ...[
                          _buildTransactionInfoSection(),
                          const SizedBox(height: 24),
                        ],

                        // Return Notes Section (only if transaction found)
                        if (_currentTransaction != null) ...[
                          _buildReturnNotesSection(),
                          const SizedBox(height: 32),

                          // Action Buttons
                          _buildActionButtons(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build projector selection section
  Widget _buildProjectorSelectionSection() {
    if (_selectedProjector == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.08),
              AppTheme.primaryColor.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
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
                        'Select Projector to Return',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Choose from issued projectors',
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
                    color: AppTheme.statusIssued.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.statusIssued.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pending_actions,
                        size: 14,
                        color: AppTheme.statusIssued,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_issuedProjectors.length} Issued',
                        style: TextStyle(
                          color: AppTheme.statusIssued,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.textTertiary.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _searchController,
                onChanged: _filterProjectors,
                decoration: InputDecoration(
                  hintText: 'Search by serial number, name, or model...',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.search,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16,
                  ),
                ),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Projectors List
            if (_isSearching) ...[
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading issued projectors...',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_filteredProjectors.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.textTertiary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      color: AppTheme.textSecondary,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No projectors found',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search criteria',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredProjectors.length,
                  itemBuilder: (context, index) {
                    final projector = _filteredProjectors[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.textTertiary.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        onTap: () => _selectProjector(projector),
                        leading: Container(
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
                        title: Text(
                          projector.serialNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (projector.projectorName.isNotEmpty)
                              Text(
                                projector.projectorName,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            if (projector.modelName.isNotEmpty)
                              Text(
                                projector.modelName,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.statusIssued.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.statusIssued.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            'Issued',
                            style: TextStyle(
                              color: AppTheme.statusIssued,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Show selected projector info
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.statusAvailable.withValues(alpha: 0.08),
            AppTheme.statusAvailable.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.statusAvailable.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.statusAvailable.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.statusAvailable.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppTheme.statusAvailable,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Projector',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Ready for return processing',
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
                  color: AppTheme.statusAvailable.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.statusAvailable.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: AppTheme.statusAvailable,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Selected',
                      style: TextStyle(
                        color: AppTheme.statusAvailable,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Projector Details
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
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Change Projector Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedProjector = null;
                  _currentTransaction = null;
                });
              },
              icon: const Icon(Icons.change_circle),
              label: const Text('Change Projector'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build transaction information section
  Widget _buildTransactionInfoSection() {
    if (_currentTransaction == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.errorColor.withValues(alpha: 0.08),
              AppTheme.errorColor.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.errorColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.errorColor.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                Icons.error_outline,
                color: AppTheme.errorColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction Not Found',
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No active transaction found for this projector',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final daysIssued = DateTime.now()
        .difference(_currentTransaction!.dateIssued)
        .inDays;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentColor.withValues(alpha: 0.08),
            AppTheme.accentColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.receipt_long,
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
                      'Transaction Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Active issuance information',
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
                  color: daysIssued > 14
                      ? Colors.orange.withValues(alpha: 0.1)
                      : AppTheme.statusIssued.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: daysIssued > 14
                        ? Colors.orange.withValues(alpha: 0.3)
                        : AppTheme.statusIssued.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      daysIssued > 14 ? Icons.warning : Icons.schedule,
                      size: 14,
                      color: daysIssued > 14
                          ? Colors.orange
                          : AppTheme.statusIssued,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      daysIssued > 14 ? 'Long-term' : '${daysIssued}d',
                      style: TextStyle(
                        color: daysIssued > 14
                            ? Colors.orange
                            : AppTheme.statusIssued,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Transaction detail cards
          Row(
            children: [
              Expanded(
                child: _buildDetailCard(
                  icon: Icons.person,
                  title: 'Issued To',
                  value: _currentTransaction!.lecturerName,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailCard(
                  icon: Icons.schedule,
                  title: 'Issue Date',
                  value: _formatShortDate(_currentTransaction!.dateIssued),
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            icon: Icons.timer,
            title: 'Duration',
            value: _getDurationString(_currentTransaction!.duration),
            color: AppTheme.accentColor,
            isWide: true,
          ),

          // Transaction ID (smaller card)
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.textTertiary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.tag, color: AppTheme.textSecondary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'ID: ',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    _currentTransaction!.id,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to build detail cards
  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    bool isWide = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isWide
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
    );
  }

  /// Format date for short display
  String _formatShortDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Build return notes section
  Widget _buildReturnNotesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.statusAvailable.withValues(alpha: 0.06),
            AppTheme.statusAvailable.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.statusAvailable.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.statusAvailable.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.statusAvailable.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.note_add,
                  color: AppTheme.statusAvailable,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Return Notes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Document the projector condition and return details',
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
                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 14,
                      color: AppTheme.accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Optional',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Form field
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.textTertiary.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextFormField(
              controller: _returnNotesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Enter any notes about the projector condition, accessories returned, or observations...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.statusAvailable.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_note,
                    color: AppTheme.statusAvailable,
                    size: 20,
                  ),
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16,
                ),
              ),
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),

          // Smart suggestions for return notes
          if (_returnNoteSuggestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.tips_and_updates,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Quick Suggestions:',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _returnNoteSuggestions
                  .take(4)
                  .map(
                    (suggestion) => ActionChip(
                      label: Text(
                        suggestion,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        if (_returnNotesController.text.isEmpty) {
                          _returnNotesController.text = suggestion;
                        } else {
                          _returnNotesController.text += '; $suggestion';
                        }
                      },
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.08,
                      ),
                      labelStyle: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      ),
                      elevation: 0,
                      pressElevation: 2,
                    ),
                  )
                  .toList(),
            ),
          ],
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

  /// Get duration string
  String _getDurationString(Duration? duration) {
    if (duration == null) return 'Unknown';

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '$days days, $hours hours';
    } else if (hours > 0) {
      return '$hours hours, $minutes minutes';
    } else {
      return '$minutes minutes';
    }
  }

  /// Build enhanced header
  Widget _buildEnhancedHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _selectedProjector != null
              ? [
                  AppTheme.secondaryColor.withValues(alpha: 0.1),
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                ]
              : [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.secondaryColor.withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedProjector != null
                  ? AppTheme.secondaryColor.withValues(alpha: 0.15)
                  : AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedProjector != null
                    ? AppTheme.secondaryColor.withValues(alpha: 0.3)
                    : AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              _selectedProjector != null
                  ? Icons.assignment_return
                  : Icons.search,
              color: _selectedProjector != null
                  ? AppTheme.secondaryColor
                  : AppTheme.primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedProjector != null
                      ? 'Return Projector'
                      : 'Select Projector',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedProjector != null
                      ? 'Process projector return from lecturer'
                      : 'Choose a projector to begin the return process',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                if (_selectedProjector != null) ...[
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
                          Icons.qr_code,
                          size: 16,
                          color: AppTheme.secondaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedProjector!.serialNumber,
                          style: TextStyle(
                            color: AppTheme.secondaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
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
                          Icons.search,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Select Projector',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  /// Build action buttons
  Widget _buildActionButtons() {
    final canReturn = _currentTransaction != null && !_isLoading;

    return Column(
      children: [
        // Validation status indicator
        if (!_isEligibleForReturn && _validationMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
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
                  Icons.warning_rounded,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _validationMessage!,
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Action buttons
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.secondaryColor, width: 2),
                ),
                child: OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      size: 18,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  label: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.secondaryColor,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: canReturn
                      ? [
                          BoxShadow(
                            color: AppTheme.statusAvailable.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: ElevatedButton.icon(
                  onPressed: canReturn ? _returnProjector : null,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.assignment_returned,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                  label: Text(
                    _isLoading ? 'Processing...' : 'Return Projector',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canReturn
                        ? AppTheme.statusAvailable
                        : AppTheme.textTertiary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: canReturn ? 6 : 0,
                    shadowColor: canReturn
                        ? AppTheme.statusAvailable.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Quick action hint for eligible returns
        if (_isEligibleForReturn) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.statusAvailable.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.statusAvailable.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.statusAvailable,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This projector is eligible for return and will be marked as available.',
                    style: TextStyle(
                      color: AppTheme.statusAvailable,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
