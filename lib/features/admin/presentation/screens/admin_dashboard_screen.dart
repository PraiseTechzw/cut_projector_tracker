import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';
import '../../../../shared/models/lecturer.dart';
import '../../../../shared/models/transaction.dart';

/// Admin dashboard screen with system overview and analytics
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _systemStats = {};
  List<ProjectorTransaction> _recentTransactions = [];
  List<Projector> _lowStockProjectors = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// Load dashboard data
  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final firestoreService = ref.read(firestoreServiceProvider);

      // Load all data streams
      final projectorsStream = firestoreService.getProjectors();
      final lecturersStream = firestoreService.getLecturers();
      final transactionsStream = firestoreService.getTransactions();
      final activeTransactionsStream = firestoreService.getActiveTransactions();

      // Get first values from streams
      final projectors = await projectorsStream.first;
      final lecturers = await lecturersStream.first;
      final transactions = await transactionsStream.first;
      final activeTransactions = await activeTransactionsStream.first;

      // Calculate system statistics
      final totalProjectors = projectors.length;
      final availableProjectors = projectors.where((p) => p.isAvailable).length;
      final issuedProjectors = projectors.where((p) => p.isIssued).length;
      final maintenanceProjectors = projectors.where((p) => p.isMaintenance).length;
      final totalLecturers = lecturers.length;
      final totalTransactions = transactions.length;
      final activeTransactionsCount = activeTransactions.length;

      // Calculate utilization rate
      final utilizationRate = totalProjectors > 0 
          ? ((issuedProjectors / totalProjectors) * 100).toStringAsFixed(1)
          : '0.0';

      // Get recent transactions (last 5)
      final recentTransactions = transactions.take(5).toList();

      // Get projectors with low availability (less than 20% available)
      final lowStockThreshold = (totalProjectors * 0.2).ceil();
      final lowStockProjectors = availableProjectors < lowStockThreshold 
          ? projectors.where((p) => p.isAvailable).take(3).toList()
          : <Projector>[];

      setState(() {
        _systemStats = {
          'totalProjectors': totalProjectors,
          'availableProjectors': availableProjectors,
          'issuedProjectors': issuedProjectors,
          'maintenanceProjectors': maintenanceProjectors,
          'totalLecturers': totalLecturers,
          'totalTransactions': totalTransactions,
          'activeTransactions': activeTransactionsCount,
          'utilizationRate': utilizationRate,
        };
        _recentTransactions = recentTransactions;
        _lowStockProjectors = lowStockProjectors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: AppTheme.errorColor,
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
        title: const Text('Admin Dashboard'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    _buildWelcomeHeader(),
                    const SizedBox(height: 24),

                    // System Overview Cards
                    _buildSystemOverviewCards(),
                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActions(),
                    const SizedBox(height: 24),

                    // Recent Activity
                    _buildRecentActivity(),
                    const SizedBox(height: 24),

                    // System Health
                    _buildSystemHealth(),
                  ],
                ),
              ),
            ),
    );
  }

  /// Build welcome header
  Widget _buildWelcomeHeader() {
    return Container(
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
        borderRadius: BorderRadius.circular(20),
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
                  Icons.admin_panel_settings,
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
                      'Admin Dashboard',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'System overview and administrative controls',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
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
              _buildStatCard(
                'Utilization',
                '${_systemStats['utilizationRate'] ?? '0.0'}%',
                Icons.trending_up,
                Colors.white,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Active',
                '${_systemStats['activeTransactions'] ?? 0}',
                Icons.pending,
                Colors.white,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Total Users',
                '${_systemStats['totalLecturers'] ?? 0}',
                Icons.people,
                Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build system overview cards
  Widget _buildSystemOverviewCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildOverviewCard(
              'Projectors',
              '${_systemStats['totalProjectors'] ?? 0}',
              Icons.devices,
              AppTheme.primaryColor,
              [
                'Available: ${_systemStats['availableProjectors'] ?? 0}',
                'Issued: ${_systemStats['issuedProjectors'] ?? 0}',
                'Maintenance: ${_systemStats['maintenanceProjectors'] ?? 0}',
              ],
            ),
            _buildOverviewCard(
              'Transactions',
              '${_systemStats['totalTransactions'] ?? 0}',
              Icons.receipt_long,
              AppTheme.accentColor,
              [
                'Active: ${_systemStats['activeTransactions'] ?? 0}',
                'Completed: ${(_systemStats['totalTransactions'] ?? 0) - (_systemStats['activeTransactions'] ?? 0)}',
              ],
            ),
            _buildOverviewCard(
              'Lecturers',
              '${_systemStats['totalLecturers'] ?? 0}',
              Icons.people,
              AppTheme.statusAvailable,
              [
                'Total Registered',
                'Active Users',
              ],
            ),
            _buildOverviewCard(
              'System Health',
              'Good',
              Icons.health_and_safety,
              Colors.green,
              [
                'All systems operational',
                'No critical issues',
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Build overview card
  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color,
    List<String> details,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...details.map((detail) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  /// Build quick actions
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Add Projector',
                Icons.add_circle,
                AppTheme.accentColor,
                () {
                  // TODO: Navigate to add projector
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Navigate to Add Projector'),
                      backgroundColor: AppTheme.accentColor,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'Add Lecturer',
                Icons.person_add,
                AppTheme.primaryColor,
                () {
                  // TODO: Navigate to add lecturer
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Navigate to Add Lecturer'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Export Data',
                Icons.download,
                AppTheme.statusAvailable,
                () {
                  // TODO: Implement data export
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Export functionality coming soon'),
                      backgroundColor: AppTheme.statusAvailable,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'System Settings',
                Icons.settings,
                AppTheme.textSecondary,
                () {
                  // TODO: Navigate to settings
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings coming soon'),
                      backgroundColor: AppTheme.textSecondary,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build action button
  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      height: 80,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.1),
          foregroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build recent activity
  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        if (_recentTransactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.textTertiary.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 48,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recent activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentTransactions.length,
            itemBuilder: (context, index) {
              final transaction = _recentTransactions[index];
              return _buildActivityItem(transaction);
            },
          ),
      ],
    );
  }

  /// Build activity item
  Widget _buildActivityItem(ProjectorTransaction transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: transaction.isActive
              ? AppTheme.warningColor.withValues(alpha: 0.2)
              : AppTheme.statusAvailable.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: transaction.isActive
                  ? AppTheme.warningColor.withValues(alpha: 0.1)
                  : AppTheme.statusAvailable.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              transaction.isActive ? Icons.pending : Icons.check_circle,
              color: transaction.isActive
                  ? AppTheme.warningColor
                  : AppTheme.statusAvailable,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${transaction.projectorSerialNumber} → ${transaction.lecturerName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatDate(transaction.dateIssued),
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: transaction.isActive
                  ? AppTheme.warningColor.withValues(alpha: 0.1)
                  : AppTheme.statusAvailable.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              transaction.status,
              style: TextStyle(
                color: transaction.isActive
                    ? AppTheme.warningColor
                    : AppTheme.statusAvailable,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build system health
  Widget _buildSystemHealth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Health',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Systems Operational',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'No critical issues detected',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_lowStockProjectors.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: AppTheme.warningColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Low projector availability',
                        style: TextStyle(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Consider adding more projectors to meet demand',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Build stat card for header
  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
