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
  bool _isScanning = false;
  bool _isTransactionLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _scanStatus;

  // Form controllers
  final _returnNotesController = TextEditingController();
  final _searchController = TextEditingController();

  // Confetti controller
  late ConfettiController _confettiController;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Smart suggestions
  List<String> _returnNoteSuggestions = [
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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  void _setupConfetti() {
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _returnNotesController.dispose();
    _confettiController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _scanProjector() async {
    setState(() {
      _isScanning = true;
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
      setState(() {
        _isScanning = false;
      });
    }
  }

  /// Intelligent projector validation
  bool _isProjectorEligibleForReturn(Projector projector) {
    if (projector.status != AppConstants.statusIssued) {
      return false;
    }
    
    // Check if projector has been issued for too long (e.g., more than 30 days)
    if (_activeTransaction != null) {
      final daysIssued = DateTime.now().difference(_activeTransaction!.dateIssued).inDays;
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
      final daysIssued = DateTime.now().difference(_activeTransaction!.dateIssued).inDays;
      
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
      _isLoading = true;
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
            _isLoading = false;
          });
          return; // Exit the stream after finding the transaction
        }
      }

      // If we reach here, no active transaction was found
      setState(() {
        _isLoading = false;
        _errorMessage = 'No active transaction found for this projector';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _returnProjector() async {
    if (_selectedProjector == null || _activeTransaction == null) {
      setState(() {
        _errorMessage = 'Please select a projector with an active transaction';
      });
      return;
    }

    if (_selectedProjector!.status != AppConstants.statusIssued) {
      setState(() {
        _errorMessage = 'This projector is not currently issued';
      });
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetForm,
            tooltip: 'Reset Form',
          ),
        ],
      ),
      body: Stack(
        children: [
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
              padding: const EdgeInsets.all(AppConstants.largePadding),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      _buildHeader(),

                      const SizedBox(height: 32),

                      // Projector Selection
                      _buildProjectorSelection(),

                      const SizedBox(height: 24),

                      // Transaction Details
                      if (_activeTransaction != null)
                        _buildTransactionDetails(),

                      const SizedBox(height: 24),

                      // Return Notes
                      _buildReturnNotesSection(),

                      const SizedBox(height: 32),

                      // Error/Success Messages
                      if (_errorMessage != null) _buildErrorMessage(),
                      if (_successMessage != null) _buildSuccessMessage(),

                      const SizedBox(height: 24),

                      // Return Button
                      if (_activeTransaction != null) _buildReturnButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.secondaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.keyboard_return, size: 48, color: AppTheme.secondaryColor),
          const SizedBox(height: 16),
          Text(
            'Return Projector',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Process the return of a projector from a lecturer',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProjectorSelection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.video_camera_front, color: AppTheme.secondaryColor),
                const SizedBox(width: 8),
                Text(
                  'Projector Selection',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedProjector != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.secondaryColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Selected Projector',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Serial: ${_selectedProjector!.serialNumber}'),
                    Text('Status: ${_selectedProjector!.status}'),
                    if (_selectedProjector!.lastIssuedTo != null)
                      Text(
                        'Last Issued To: ${_selectedProjector!.lastIssuedTo}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _scanProjector,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Change Projector'),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _scanProjector,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scan Projector'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionDetails() {
    if (_activeTransaction == null) return const SizedBox.shrink();

    final duration = _calculateDuration(
      _activeTransaction!.dateIssued,
      DateTime.now(),
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Transaction Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Issued To: ${_activeTransaction!.lecturerName}',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AppTheme.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Issued: ${_formatDate(_activeTransaction!.dateIssued)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        color: AppTheme.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text('Duration: $duration'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnNotesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: AppTheme.secondaryColor),
                const SizedBox(width: 8),
                Text(
                  'Return Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _returnNotesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Return Notes *',
                  hintText: 'Enter any notes about the return...',
                  prefixIcon: const Icon(Icons.note_add),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadius,
                    ),
                    borderSide: BorderSide(
                      color: AppTheme.textTertiary.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadius,
                    ),
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Return notes are required for tracking purposes';
                  }
                  return null;
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
        color: AppTheme.errorColor.withOpacity(0.1),
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
        color: Colors.green.withOpacity(0.1),
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

    return ElevatedButton.icon(
      onPressed: canReturn && !_isLoading ? _returnProjector : null,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.keyboard_return),
      label: Text(_isLoading ? 'Processing Return...' : 'Return Projector'),
      style: ElevatedButton.styleFrom(
        backgroundColor: canReturn
            ? AppTheme.secondaryColor
            : AppTheme.textTertiary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
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
}
