import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';
import 'add_projector_screen.dart';
import 'edit_projector_screen.dart';
import '../../../issuance/presentation/screens/issue_projector_screen.dart';

/// Screen for viewing asset register
class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Asset Register'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _refreshAssets(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced Header with stats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.largePadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.inventory_2,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Projector Inventory',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            'Manage and track all projectors',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Consumer(
                  builder: (context, ref, child) {
                    final projectorsStream = ref.watch(
                      projectorsStreamProvider,
                    );
                    return projectorsStream.when(
                      data: (projectors) => _buildEnhancedStats(projectors),
                      loading: () => const SizedBox(height: 60),
                      error: (error, stack) => const SizedBox(height: 60),
                    );
                  },
                ),
              ],
            ),
          ),

          // Projectors List
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final projectorsStream = ref.watch(projectorsStreamProvider);

                return projectorsStream.when(
                  data: (projectors) => _buildProjectorsList(projectors),
                  loading: () => _buildLoadingState(),
                  error: (error, stack) => _buildErrorWidget(error.toString()),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNewProjector(context),
        backgroundColor: AppTheme.accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Projector'),
        elevation: 8,
        tooltip: 'Add New Projector',
      ),
    );
  }

  /// Build enhanced statistics section
  Widget _buildEnhancedStats(List<Projector> projectors) {
    final total = projectors.length;
    final available = projectors.where((p) => p.isAvailable).length;
    final issued = projectors.where((p) => p.isIssued).length;
    final maintenance = projectors.where((p) => p.isMaintenance).length;

    return Row(
      children: [
        Expanded(
          child: _buildEnhancedStatItem(
            'Total',
            total.toString(),
            Icons.inventory_2,
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildEnhancedStatItem(
            'Available',
            available.toString(),
            Icons.check_circle,
            AppTheme.statusAvailable,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildEnhancedStatItem(
            'Issued',
            issued.toString(),
            Icons.send,
            AppTheme.statusIssued,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildEnhancedStatItem(
            'Maintenance',
            maintenance.toString(),
            Icons.build,
            AppTheme.statusMaintenance,
          ),
        ),
      ],
    );
  }

  /// Build enhanced stat item
  Widget _buildEnhancedStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading Assets...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
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

  /// Build projectors list
  Widget _buildProjectorsList(List<Projector> projectors) {
    if (projectors.isEmpty) {
      return _buildEnhancedEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: projectors.length,
      itemBuilder: (context, index) {
        final projector = projectors[index];
        return _buildEnhancedProjectorCard(projector);
      },
    );
  }

  /// Build enhanced empty state
  Widget _buildEnhancedEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppConstants.largePadding),
        padding: const EdgeInsets.all(AppConstants.largePadding),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Projectors Found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Start by adding your first projector to the system',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: () => _addNewProjector(context),
                icon: const Icon(Icons.add),
                label: const Text('Add First Projector'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
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
      ),
    );
  }

  /// Build enhanced projector card
  Widget _buildEnhancedProjectorCard(Projector projector) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
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
        border: Border.all(
          color: _getStatusColor(projector.status).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with serial number, status, and quick actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.qr_code,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  projector.serialNumber,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                        color: AppTheme.textPrimary,
                                      ),
                                ),
                                if (projector.projectorName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    projector.projectorName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      projector.status,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(projector.status),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(projector.status),
                        color: _getStatusColor(projector.status),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        projector.status,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getStatusColor(projector.status),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Projector details in organized sections
            _buildDetailSection('Basic Information', [
              if (projector.modelName.isNotEmpty)
                _buildEnhancedDetailRow(
                  'Model',
                  projector.modelName,
                  Icons.model_training,
                ),
              if (projector.location != null && projector.location!.isNotEmpty)
                _buildEnhancedDetailRow(
                  'Location',
                  projector.location!,
                  Icons.location_on,
                ),
            ]),

            if (projector.lastIssuedTo != null ||
                projector.lastIssuedDate != null)
              _buildDetailSection('Last Issue', [
                if (projector.lastIssuedTo != null)
                  _buildEnhancedDetailRow(
                    'Issued To',
                    projector.lastIssuedTo!,
                    Icons.person,
                  ),
                if (projector.lastIssuedDate != null)
                  _buildEnhancedDetailRow(
                    'Issue Date',
                    _formatDate(projector.lastIssuedDate!),
                    Icons.calendar_today,
                  ),
              ]),

            if (projector.notes != null && projector.notes!.isNotEmpty)
              _buildDetailSection('Notes', [
                _buildEnhancedDetailRow(
                  'Additional Info',
                  projector.notes!,
                  Icons.note,
                ),
              ]),

            _buildDetailSection('System Information', [
              _buildEnhancedDetailRow('ID', projector.id, Icons.fingerprint),
              _buildEnhancedDetailRow(
                'Created',
                _formatDate(projector.createdAt),
                Icons.add_circle,
              ),
              _buildEnhancedDetailRow(
                'Updated',
                _formatDate(projector.updatedAt),
                Icons.update,
              ),
            ]),

            const SizedBox(height: 20),

            // Enhanced action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editProjector(context, projector),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(
                        color: AppTheme.primaryColor,
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
                  child: ElevatedButton.icon(
                    onPressed: projector.isAvailable
                        ? () => _issueProjector(context, projector)
                        : null,
                    icon: const Icon(Icons.send),
                    label: const Text('Issue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: projector.isAvailable
                          ? AppTheme.accentColor
                          : AppTheme.textTertiary,
                      foregroundColor: Colors.white,
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
      ),
    );
  }

  /// Build detail section
  Widget _buildDetailSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  /// Build enhanced detail row
  Widget _buildEnhancedDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
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
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build error widget
  Widget _buildErrorWidget(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppConstants.largePadding),
        padding: const EdgeInsets.all(AppConstants.largePadding),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline,
                size: 80,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Assets',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: _refreshAssets,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
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
      ),
    );
  }

  /// Get status icon
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Icons.check_circle;
      case 'issued':
        return Icons.send;
      case 'maintenance':
        return Icons.build;
      default:
        return Icons.info;
    }
  }

  /// Get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return AppTheme.statusAvailable;
      case 'issued':
        return AppTheme.statusIssued;
      case 'maintenance':
        return AppTheme.statusMaintenance;
      default:
        return AppTheme.textPrimary;
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Refresh assets
  void _refreshAssets() {
    ref.invalidate(projectorsStreamProvider);
  }

  /// Add new projector
  void _addNewProjector(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AddProjectorScreen()));
  }

  /// Edit projector
  void _editProjector(BuildContext context, Projector projector) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditProjectorScreen(projector: projector),
      ),
    );
  }

  /// Issue projector
  void _issueProjector(BuildContext context, Projector projector) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IssueProjectorScreen(projector: projector),
      ),
    );
  }
}
