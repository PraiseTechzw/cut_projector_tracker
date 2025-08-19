import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';
import '../../../../shared/models/transaction.dart';
import 'return_projector_screen.dart';

/// Projector return screen for processing projector returns
class ReturnsScreen extends ConsumerStatefulWidget {
  final Projector? projector; // Pre-selected projector from scanning

  const ReturnsScreen({super.key, this.projector});

  @override
  ConsumerState<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends ConsumerState<ReturnsScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  Projector? _selectedProjector;
  ProjectorTransaction? _activeTransaction;
  bool _isLoading = false;

  String? _errorMessage;
  String? _successMessage;
  String? _scanStatus;

  // Form controllers
  final _returnNotesController = TextEditingController();
  final _searchController = TextEditingController();

  // Projector listing
  List<Projector> _issuedProjectors = [];
  List<Projector> _filteredProjectors = [];
  bool _isLoadingProjectors = false;
  bool _showProjectorList = false;

  // Confetti controller
  late ConfettiController _confettiController;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  // Smart suggestions
  final List<String> _returnNoteSuggestions = [
    'Projector in good condition',
    'Minor wear and tear',
    'Lens cleaned',
    'Cable included',
    'Remote control working',
    'No damage reported',
    'Ready for next use',
    'Maintenance recommended',
  ];

  @override
  void initState() {
    super.initState();
    _selectedProjector = widget.projector;
    _setupAnimations();
    _setupConfetti();
    if (_selectedProjector != null) {
      _lookupActiveTransaction();
    }
    // Load issued projectors for listing
    _loadIssuedProjectors();
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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
    _pulseController.repeat(reverse: true);
  }

  void _setupConfetti() {
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  /// Load all issued projectors from Firestore
  Future<void> _loadIssuedProjectors() async {
    setState(() {
      _isLoadingProjectors = true;
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
          _isLoadingProjectors = false;
        });
        break; // Exit after first successful load
      }
    } catch (e) {
      setState(() {
        _isLoadingProjectors = false;
        _errorMessage = 'Error loading issued projectors: $e';
      });
    }
  }

  /// Filter projectors based on search query
  void _filterProjectors(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProjectors = _issuedProjectors;
      });
    } else {
      final filtered = _issuedProjectors.where((projector) {
        return projector.serialNumber.toLowerCase().contains(
              query.toLowerCase(),
            ) ||
            projector.modelName.toLowerCase().contains(query.toLowerCase()) ||
            projector.projectorName.toLowerCase().contains(query.toLowerCase());
      }).toList();

      setState(() {
        _filteredProjectors = filtered;
      });
    }
  }

  /// Select a projector from the list
  void _selectProjectorFromList(Projector projector) {
    setState(() {
      _selectedProjector = projector;
      _activeTransaction = null;
      _showProjectorList = false;
    });

    // Look up the transaction for the selected projector
    _lookupActiveTransaction();
  }

  @override
  void dispose() {
    _returnNotesController.dispose();
    _searchController.dispose();
    _confettiController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _scanProjector() async {
    setState(() {
      _scanStatus = 'Scanning projector...';
      _errorMessage = null;
    });

    try {
      final result = await context.push(
        '/scan-projector',
        extra: {'purpose': 'return'},
      );

      if (result != null && result is Projector) {
        setState(() {
          _selectedProjector = result;
          _activeTransaction = null;
          _scanStatus = 'Projector found! Looking up transaction...';
        });

        // Intelligent transaction lookup with better error handling
        await _lookupActiveTransaction();

        setState(() {
          _scanStatus = null;
        });
      } else {
        setState(() {
          _scanStatus = 'No projector selected';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error during scanning: $e';
        _scanStatus = null;
      });
    } finally {
      // Scanning completed
    }
  }

  /// Intelligent projector validation
  bool _isProjectorEligibleForReturn(Projector projector) {
    if (projector.status != AppConstants.statusIssued) {
      return false;
    }

    // Check if projector has been issued for too long (e.g., more than 30 days)
    if (_activeTransaction != null) {
      final daysIssued = DateTime.now()
          .difference(_activeTransaction!.dateIssued)
          .inDays;
      if (daysIssued > 30) {
        return false;
      }
    }

    return true;
  }

  /// Get intelligent return note suggestions based on projector condition
  List<String> _getSmartSuggestions() {
    if (_selectedProjector == null) return _returnNoteSuggestions;

    // Filter suggestions based on projector status and transaction duration
    List<String> suggestions = [..._returnNoteSuggestions];

    if (_activeTransaction != null) {
      final daysIssued = DateTime.now()
          .difference(_activeTransaction!.dateIssued)
          .inDays;

      if (daysIssued > 7) {
        suggestions.add('Extended use period - check for wear');
        suggestions.add('May need maintenance after long use');
      }

      if (daysIssued > 14) {
        suggestions.add('Long-term usage - thorough inspection needed');
      }
    }

    return suggestions;
  }

  Future<void> _lookupActiveTransaction() async {
    if (_selectedProjector == null) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final transactionsStream = firestoreService.getActiveTransactions();

      // Listen to the stream and find the active transaction
      await for (final transactions in transactionsStream) {
        final activeTransaction = transactions
            .where(
              (transaction) =>
                  transaction.projectorId == _selectedProjector!.id,
            )
            .firstOrNull;

        if (activeTransaction != null) {
          setState(() {
            _activeTransaction = activeTransaction;
          });

          // Auto-fill return notes with intelligent suggestions
          _autoFillReturnNotes();
          return; // Exit the stream after finding the transaction
        }
      }

      // If we reach here, no active transaction was found
      setState(() {
        _errorMessage = 'No active transaction found for this projector';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error looking up transaction: $e';
      });
    }
  }

  /// Auto-fill return notes with intelligent suggestions
  void _autoFillReturnNotes() {
    if (_activeTransaction == null || _selectedProjector == null) return;

    final daysIssued = DateTime.now()
        .difference(_activeTransaction!.dateIssued)
        .inDays;
    String autoNote = '';

    if (daysIssued <= 1) {
      autoNote = 'Same day return - projector in excellent condition';
    } else if (daysIssued <= 3) {
      autoNote = 'Short-term use - minimal wear expected';
    } else if (daysIssued <= 7) {
      autoNote = 'Weekly use - standard inspection required';
    } else if (daysIssued <= 14) {
      autoNote = 'Extended use - thorough inspection recommended';
    } else {
      autoNote = 'Long-term use - maintenance may be required';
    }

    if (_returnNotesController.text.isEmpty) {
      _returnNotesController.text = autoNote;
    }
  }

  Future<void> _returnProjector() async {
    if (_selectedProjector == null || _activeTransaction == null) {
      setState(() {
        _errorMessage = 'Please select a projector with an active transaction';
      });
      return;
    }

    // Intelligent validation
    if (!_isProjectorEligibleForReturn(_selectedProjector!)) {
      String errorMsg = 'This projector cannot be returned';

      if (_selectedProjector!.status != AppConstants.statusIssued) {
        errorMsg = 'This projector is not currently issued';
      } else if (_activeTransaction != null) {
        final daysIssued = DateTime.now()
            .difference(_activeTransaction!.dateIssued)
            .inDays;
        if (daysIssued > 30) {
          errorMsg =
              'Projector has been issued for over 30 days. Please contact administrator.';
        }
      }

      setState(() {
        _errorMessage = errorMsg;
      });
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Show confirmation dialog for long-term returns
    if (_activeTransaction != null) {
      final daysIssued = DateTime.now()
          .difference(_activeTransaction!.dateIssued)
          .inDays;
      if (daysIssued > 14) {
        final shouldProceed = await _showLongTermReturnConfirmation(daysIssued);
        if (!shouldProceed) return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Return projector (updates transaction and projector status)
      await firestoreService.returnProjector(
        transactionId: _activeTransaction!.id,
        projectorId: _selectedProjector!.id,
        returnNotes: _returnNotesController.text.trim(),
      );

      setState(() {
        _isLoading = false;
        _successMessage = 'Projector returned successfully!';
      });

      // Play confetti
      _confettiController.play();

      // Show success dialog
      _showSuccessDialog();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error returning projector: $e';
      });
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

  /// Navigate to detailed return screen
  void _navigateToDetailedReturn() {
    if (_selectedProjector != null && _activeTransaction != null) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => ReturnProjectorScreen(
                projector: _selectedProjector!,
                activeTransaction: _activeTransaction,
              ),
            ),
          )
          .then((result) {
            // Handle return result
            if (result == true) {
              // Return was successful, show success message
              setState(() {
                _successMessage = 'Projector returned successfully!';
              });

              // Play confetti
              _confettiController.play();

              // Reset form after a delay
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  _resetForm();
                }
              });
            }
          });
    }
  }

  /// Toggle projector selection list
  void _navigateToProjectorSelection() {
    setState(() {
      _showProjectorList = !_showProjectorList;
      if (_showProjectorList) {
        _searchController.clear();
        _filteredProjectors = _issuedProjectors;
      }
    });
  }

  /// Navigate to detailed return screen with current projector
  void _navigateToDetailedReturnScreen() {
    if (_selectedProjector != null && _activeTransaction != null) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => ReturnProjectorScreen(
                projector: _selectedProjector!,
                activeTransaction: _activeTransaction,
              ),
            ),
          )
          .then((result) {
            // Handle return result
            if (result == true) {
              // Return was successful, show success message
              setState(() {
                _successMessage = 'Projector returned successfully!';
              });

              // Play confetti
              _confettiController.play();

              // Reset form after a delay
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  _resetForm();
                }
              });
            }
          });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            const Text('Projector Returned'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'Projector',
              _selectedProjector!.serialNumber,
              Icons.qr_code,
            ),
            _buildDetailRow(
              'Returned From',
              _activeTransaction!.lecturerName,
              Icons.person,
            ),
            _buildDetailRow(
              'Issue Date',
              _formatDate(_activeTransaction!.dateIssued),
              Icons.send,
            ),
            _buildDetailRow(
              'Return Date',
              _formatDate(DateTime.now()),
              Icons.undo,
            ),
            if (_activeTransaction!.purpose != null &&
                _activeTransaction!.purpose!.isNotEmpty)
              _buildDetailRow(
                'Purpose',
                _activeTransaction!.purpose!,
                Icons.info,
              ),
            if (_activeTransaction!.notes != null &&
                _activeTransaction!.notes!.isNotEmpty)
              _buildDetailRow(
                'Issue Notes',
                _activeTransaction!.notes!,
                Icons.note,
              ),
            if (_returnNotesController.text.isNotEmpty)
              _buildDetailRow(
                'Return Notes',
                _returnNotesController.text,
                Icons.note_add,
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetForm();
            },
            child: const Text('Return Another'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/home');
            },
            child: const Text('Go to Home'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _selectedProjector = null;
      _activeTransaction = null;
      _returnNotesController.clear();
      _errorMessage = null;
      _successMessage = null;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _calculateDuration(DateTime issued, DateTime returned) {
    final duration = returned.difference(issued);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetForm,
            tooltip: 'Reset Form',
          ),
        ],
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

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
              colors: [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
                Colors.orange,
                Colors.pink,
                Colors.purple,
                Colors.teal,
              ],
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Enhanced Header
                          _buildEnhancedHeader(),
                          const SizedBox(height: 24),

                          // Progress Steps
                          _buildProgressSteps(),
                          const SizedBox(height: 24),

                          // Projector Selection
                          _buildProjectorSelection(),

                          // Projector List (when showProjectorList is true)
                          if (_showProjectorList) ...[
                            const SizedBox(height: 24),
                            _buildProjectorList(),
                          ],

                          // Scanning Status
                          if (_scanStatus != null) _buildScanStatus(),

                          const SizedBox(height: 24),

                          // Transaction Details
                          if (_activeTransaction != null)
                            _buildTransactionDetails(),

                          const SizedBox(height: 24),

                          // Connection Status
                          _buildConnectionStatus(),

                          const SizedBox(height: 24),

                          // Return Notes
                          _buildReturnNotesSection(),

                          const SizedBox(height: 32),

                          // Error/Success Messages
                          if (_errorMessage != null) _buildErrorMessage(),
                          if (_successMessage != null) _buildSuccessMessage(),

                          const SizedBox(height: 24),

                          // Return Buttons
                          if (_activeTransaction != null) ...[
                            _buildReturnButton(),
                            const SizedBox(height: 12),
                            _buildQuickReturnButton(),
                          ],
                        ],
                      ),
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

  /// Build progress steps indicator
  Widget _buildProgressSteps() {
    final currentStep = _selectedProjector == null
        ? 1
        : _activeTransaction == null
        ? 2
        : 3;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.textTertiary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Return Process Progress',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStepItem(
                1,
                'Select Projector',
                Icons.qr_code_scanner,
                currentStep >= 1,
              ),
              _buildStepConnector(currentStep >= 2),
              _buildStepItem(
                2,
                'Load Transaction',
                Icons.receipt_long,
                currentStep >= 2,
              ),
              _buildStepConnector(currentStep >= 3),
              _buildStepItem(
                3,
                'Process Return',
                Icons.assignment_return,
                currentStep >= 3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(
    int step,
    String label,
    IconData icon,
    bool isCompleted,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.secondaryColor
                  : AppTheme.textTertiary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isCompleted
                    ? AppTheme.secondaryColor
                    : AppTheme.textTertiary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isCompleted ? Colors.white : AppTheme.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isCompleted
                  ? AppTheme.secondaryColor
                  : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Container(
      width: 20,
      height: 2,
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.secondaryColor
            : AppTheme.textTertiary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.secondaryColor.withValues(alpha: 0.1),
            AppTheme.primaryColor.withValues(alpha: 0.05),
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
              color: AppTheme.secondaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.secondaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              Icons.keyboard_return,
              color: AppTheme.secondaryColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Return Projector',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedProjector != null
                      ? 'Processing return for ${_selectedProjector!.serialNumber}'
                      : 'Select a projector to process its return',
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
                          'Projector Selected',
                          style: TextStyle(
                            color: AppTheme.secondaryColor,
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
                            Icons.info_outline,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedProjector!.modelName,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectorSelection() {
    if (_selectedProjector == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.secondaryColor.withValues(alpha: 0.2),
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
                    color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: AppTheme.secondaryColor,
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
                          color: AppTheme.secondaryColor,
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
                      'Please scan a projector to begin the return process.',
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
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _scanProjector,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Projector'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                      ),
                      elevation: 4,
                      shadowColor: AppTheme.secondaryColor.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToProjectorSelection,
                    icon: Icon(_showProjectorList ? Icons.close : Icons.list),
                    label: Text(
                      _showProjectorList
                          ? 'Hide List'
                          : 'Show Issued Projectors',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showProjectorList
                          ? AppTheme.errorColor
                          : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                      ),
                      elevation: 4,
                      shadowColor:
                          (_showProjectorList
                                  ? AppTheme.errorColor
                                  : AppTheme.primaryColor)
                              .withValues(alpha: 0.3),
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
        color: AppTheme.secondaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.2),
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
                  color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.qr_code,
                  color: AppTheme.secondaryColor,
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
                      Icons.check_circle,
                      size: 16,
                      color: AppTheme.secondaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Selected',
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanProjector,
                  icon: const Icon(Icons.change_circle),
                  label: const Text('Change Projector'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.secondaryColor,
                    side: BorderSide(
                      color: AppTheme.secondaryColor,
                      width: 1.5,
                    ),
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
                  onPressed: _navigateToDetailedReturn,
                  icon: const Icon(Icons.assignment_return),
                  label: const Text('Process Return'),
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
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
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
    );
  }

  Widget _buildTransactionDetails() {
    if (_activeTransaction == null) return const SizedBox.shrink();

    final duration = _calculateDuration(
      _activeTransaction!.dateIssued,
      DateTime.now(),
    );

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
                      'Active Transaction',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Current issuance details',
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
                      size: 16,
                      color: AppTheme.statusIssued,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Active',
                      style: TextStyle(
                        color: AppTheme.statusIssued,
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

          // Transaction Details Cards
          Row(
            children: [
              Expanded(
                child: _buildTransactionDetailCard(
                  icon: Icons.person,
                  title: 'Issued To',
                  value: _activeTransaction!.lecturerName,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTransactionDetailCard(
                  icon: Icons.schedule,
                  title: 'Issue Date',
                  value: _formatShortDate(_activeTransaction!.dateIssued),
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTransactionDetailCard(
            icon: Icons.timer,
            title: 'Duration',
            value: duration,
            color: AppTheme.accentColor,
            isWide: true,
          ),

          // Purpose if available
          if (_activeTransaction!.purpose != null &&
              _activeTransaction!.purpose!.isNotEmpty) ...[
            const SizedBox(height: 16),
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
                        Icons.assignment,
                        color: AppTheme.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Purpose',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _activeTransaction!.purpose!,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.4,
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

  /// Helper method to build transaction detail cards
  Widget _buildTransactionDetailCard({
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
                      'Document the projector condition',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: IconButton(
                  onPressed: _showSmartSuggestions,
                  icon: Icon(
                    Icons.lightbulb_outline,
                    color: AppTheme.primaryColor,
                  ),
                  tooltip: 'Smart Suggestions',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Form field
          Form(
            key: _formKey,
            child: Container(
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
                  labelText: 'Return Notes *',
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
                  labelStyle: TextStyle(
                    color: AppTheme.statusAvailable,
                    fontWeight: FontWeight.w600,
                  ),
                  errorStyle: TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  height: 1.4,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Return notes are required for tracking purposes';
                  }
                  if (value.trim().length < 10) {
                    return 'Please provide more detailed notes (minimum 10 characters)';
                  }
                  return null;
                },
              ),
            ),
          ),

          // Smart suggestions chips
          if (_selectedProjector != null) ...[
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
              children: _getSmartSuggestions()
                  .take(6)
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

  /// Show smart suggestions modal
  void _showSmartSuggestions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Smart Suggestions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Based on projector usage and condition:',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _getSmartSuggestions().length,
                itemBuilder: (context, index) {
                  final suggestion = _getSmartSuggestions()[index];
                  return ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(suggestion),
                    onTap: () {
                      if (_returnNotesController.text.isEmpty) {
                        _returnNotesController.text = suggestion;
                      } else {
                        _returnNotesController.text += '; $suggestion';
                      }
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.errorColor),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.errorColor),
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _successMessage!,
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnButton() {
    final canReturn =
        _selectedProjector != null &&
        _activeTransaction != null &&
        _selectedProjector!.status == AppConstants.statusIssued;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: canReturn
            ? [
                BoxShadow(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ElevatedButton.icon(
        onPressed: canReturn && !_isLoading
            ? _navigateToDetailedReturnScreen
            : null,
        icon: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.assignment_return,
                  size: 20,
                  color: Colors.white,
                ),
              ),
        label: Text(
          _isLoading ? 'Processing Return...' : 'Process Detailed Return',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canReturn
              ? AppTheme.secondaryColor
              : AppTheme.textTertiary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: canReturn ? 6 : 0,
          shadowColor: canReturn
              ? AppTheme.secondaryColor.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
    );
  }

  /// Build detail row for transaction details
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
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
      ),
    );
  }

  /// Build scanning status indicator
  Widget _buildScanStatus() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.primaryColor.withValues(alpha: 0.05),
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
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scanning in Progress',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _scanStatus!,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  /// Build connection status indicator
  Widget _buildConnectionStatus() {
    if (_selectedProjector == null || _activeTransaction == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentColor.withValues(alpha: 0.1),
            AppTheme.accentColor.withValues(alpha: 0.05),
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
            color: AppTheme.accentColor.withValues(alpha: 0.08),
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
              color: AppTheme.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(Icons.link, color: AppTheme.accentColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Screen Connection Status',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connected to ReturnProjectorScreen for detailed processing',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  'Connected',
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
    );
  }

  /// Build projector list for selection
  Widget _buildProjectorList() {
    if (_isLoadingProjectors) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.textTertiary.withValues(alpha: 0.2),
          ),
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading issued projectors...'),
            ],
          ),
        ),
      );
    }

    if (_issuedProjectors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.textTertiary.withValues(alpha: 0.2),
          ),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text('No issued projectors found'),
              SizedBox(height: 8),
              Text(
                'All projectors are currently available',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
                ),
                child: Icon(Icons.list, color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Issued Projectors',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_filteredProjectors.length} of ${_issuedProjectors.length} projectors',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showProjectorList = false;
                  });
                },
                icon: Icon(Icons.close, color: AppTheme.textSecondary),
                tooltip: 'Close List',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: _filterProjectors,
            decoration: InputDecoration(
              hintText: 'Search by serial number, model, or name...',
              prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
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
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: AppTheme.backgroundColor,
            ),
          ),
          const SizedBox(height: 20),

          // Projector List
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredProjectors.length,
              itemBuilder: (context, index) {
                final projector = _filteredProjectors[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _selectProjectorFromList(projector),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.textTertiary.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.video_camera_front,
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
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
                                    ),
                                  ),
                                ],
                                if (projector.projectorName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    projector.projectorName,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.statusIssued.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.statusIssued.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_forward,
                                  size: 16,
                                  color: AppTheme.statusIssued,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Select',
                                  style: TextStyle(
                                    color: AppTheme.statusIssued,
                                    fontSize: 12,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build quick return button
  Widget _buildQuickReturnButton() {
    final isEnabled =
        _selectedProjector != null && _activeTransaction != null && !_isLoading;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? AppTheme.primaryColor
              : AppTheme.textTertiary.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: OutlinedButton.icon(
        onPressed: isEnabled ? _returnProjector : null,
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isEnabled
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : AppTheme.textTertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.flash_on,
            size: 20,
            color: isEnabled ? AppTheme.primaryColor : AppTheme.textTertiary,
          ),
        ),
        label: Text(
          'Quick Return',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: isEnabled ? AppTheme.primaryColor : AppTheme.textTertiary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: isEnabled
              ? AppTheme.primaryColor
              : AppTheme.textTertiary,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }

  /// Clear projector selection
  void _clearProjectorSelection() {
    setState(() {
      _selectedProjector = null;
      _activeTransaction = null;
      _returnNotesController.clear();
      _errorMessage = null;
      _successMessage = null;
    });
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
}
