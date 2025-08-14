import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';
import 'add_projector_screen.dart';

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
          // Header with stats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Projector Inventory',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final projectorsStream = ref.watch(
                      projectorsStreamProvider,
                    );
                    return projectorsStream.when(
                      data: (projectors) => _buildStats(projectors),
                      loading: () => const SizedBox(height: 40),
                      error: (error, stack) => const SizedBox(height: 40),
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
      ),
    );
  }

  /// Build statistics section
  Widget _buildStats(List<Projector> projectors) {
    final total = projectors.length;
    final available = projectors.where((p) => p.isAvailable).length;
    final issued = projectors.where((p) => p.isIssued).length;
    final maintenance = projectors.where((p) => p.isMaintenance).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Total', total.toString(), AppTheme.primaryColor),
        _buildStatItem(
          'Available',
          available.toString(),
          AppTheme.statusAvailable,
        ),
        _buildStatItem('Issued', issued.toString(), AppTheme.statusIssued),
        _buildStatItem(
          'Maintenance',
          maintenance.toString(),
          AppTheme.statusMaintenance,
        ),
      ],
    );
  }

  /// Build individual stat item
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Build projectors list
  Widget _buildProjectorsList(List<Projector> projectors) {
    if (projectors.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: projectors.length,
      itemBuilder: (context, index) {
        final projector = projectors[index];
        return _buildProjectorCard(projector);
      },
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 24),
          Text(
            'No Projectors Found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start by adding your first projector to the system',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _addNewProjector(context),
            icon: const Icon(Icons.add),
            label: const Text('Add First Projector'),
          ),
        ],
      ),
    );
  }

  /// Build individual projector card
  Widget _buildProjectorCard(Projector projector) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with serial number and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projector.serialNumber,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (projector.projectorName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          projector.projectorName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
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
                    color: _getStatusColor(
                      projector.status,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(projector.status),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    projector.status,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getStatusColor(projector.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Projector details
            _buildDetailRow('ID', projector.id),
            if (projector.modelName.isNotEmpty)
              _buildDetailRow('Model', projector.modelName),
            if (projector.location != null && projector.location!.isNotEmpty)
              _buildDetailRow('Location', projector.location!),
            if (projector.lastIssuedTo != null)
              _buildDetailRow('Last Issued To', projector.lastIssuedTo!),
            if (projector.lastIssuedDate != null)
              _buildDetailRow(
                'Last Issued',
                _formatDate(projector.lastIssuedDate!),
              ),
            if (projector.lastReturnDate != null)
              _buildDetailRow(
                'Last Returned',
                _formatDate(projector.lastReturnDate!),
              ),
            if (projector.notes != null && projector.notes!.isNotEmpty)
              _buildDetailRow('Notes', projector.notes!),
            _buildDetailRow('Created', _formatDate(projector.createdAt)),
            _buildDetailRow('Updated', _formatDate(projector.updatedAt)),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editProjector(context, projector),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
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
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build detail row
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  /// Build error widget
  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: AppTheme.errorColor),
          const SizedBox(height: 24),
          Text(
            'Error Loading Assets',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.errorColor,
              fontWeight: FontWeight.w600,
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
          ElevatedButton.icon(
            onPressed: _refreshAssets,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
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
    // TODO: Implement edit projector screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Issue projector
  void _issueProjector(BuildContext context, Projector projector) {
    // TODO: Navigate to issuance screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigating to issuance screen...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
