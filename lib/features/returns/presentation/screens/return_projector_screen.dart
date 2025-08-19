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
  bool _isLoading = false;
  bool _isValidating = false;
  ProjectorTransaction? _currentTransaction;

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
    _setupAnimations();
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
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.statusAvailable.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.assignment_return,
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
                            'Return Projector',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            'Process projector return from lecturer',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Projector Information Section
                _buildProjectorInfoSection(),
                const SizedBox(height: 24),

                // Transaction Information Section
                _buildTransactionInfoSection(),
                const SizedBox(height: 24),

                // Return Notes Section
                _buildReturnNotesSection(),
                const SizedBox(height: 32),

                // Action Buttons
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
                        onPressed: (_isLoading || _currentTransaction == null)
                            ? null
                            : _returnProjector,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentTransaction != null
                              ? AppTheme.statusAvailable
                              : AppTheme.textTertiary,
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
                                'Return Projector',
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
      ),
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
        ],
      ),
    );
  }

  /// Build transaction information section
  Widget _buildTransactionInfoSection() {
    if (_currentTransaction == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No active transaction found for this projector',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.errorColor),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 12),
              Text(
                'Transaction Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Issued To', _currentTransaction!.lecturerName),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Issue Date',
            _formatDate(_currentTransaction!.dateIssued),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Duration',
            _getDurationString(_currentTransaction!.duration),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Transaction ID', _currentTransaction!.id),
        ],
      ),
    );
  }

  /// Build return notes section
  Widget _buildReturnNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.statusAvailable.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.note,
                size: 16,
                color: AppTheme.statusAvailable,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Return Notes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Optional: Add any notes about the return or projector condition',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _returnNotesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter return notes...',
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
              borderSide: BorderSide(color: AppTheme.statusAvailable, width: 2),
            ),
          ),
        ),
      ],
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
}
