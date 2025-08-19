import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';
import '../../../../shared/models/transaction.dart';

/// Home dashboard screen with system overview and quick actions
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _systemStats = {};
  List<ProjectorTransaction> _recentTransactions = [];
  List<Projector> _recentProjectors = [];

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
      final availableProjectors = projectors
          .where((p) => p.status == AppConstants.statusAvailable)
          .length;
      final issuedProjectors = projectors
          .where((p) => p.status == AppConstants.statusIssued)
          .length;
      final maintenanceProjectors = projectors
          .where((p) => p.status == AppConstants.statusMaintenance)
          .length;
      final totalLecturers = lecturers.length;
      final totalTransactions = transactions.length;
      final activeTransactionsCount = activeTransactions.length;

      // Calculate utilization rate
      final utilizationRate = totalProjectors > 0
          ? ((issuedProjectors / totalProjectors) * 100).toStringAsFixed(1)
          : '0.0';

      // Get recent transactions (last 5)
      final recentTransactions = transactions.take(5).toList();

      // Get recent projectors (last 3)
      final recentProjectors = projectors.take(3).toList();

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
        _recentProjectors = recentProjectors;
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: AppTheme.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    _buildWelcomeHeader(),
                    const SizedBox(height: 24),

                    // System Statistics
                    _buildSystemStats(),
                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActions(),
                    const SizedBox(height: 24),

                    // Recent Activity
                    _buildRecentActivity(),
                    const SizedBox(height: 24),

                    // Quick Stats Cards
                    _buildQuickStatsCards(),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.home, size: 32, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to CUT Projector Tracker',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'Manage your projector inventory efficiently',
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
          Text(
            _getGreeting(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build system statistics
  Widget _buildSystemStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
            _buildStatCard(
              'Total Projectors',
              _systemStats['totalProjectors']?.toString() ?? '0',
              Icons.inventory,
              AppTheme.primaryColor,
              [
                '${_systemStats['availableProjectors'] ?? 0} Available',
                '${_systemStats['issuedProjectors'] ?? 0} Issued',
                '${_systemStats['maintenanceProjectors'] ?? 0} Maintenance',
              ],
            ),
            _buildStatCard(
              'Total Lecturers',
              _systemStats['totalLecturers']?.toString() ?? '0',
              Icons.people,
              AppTheme.accentColor,
              [
                'Active users in system',
                'Department management',
                'Contact information',
              ],
            ),
            _buildStatCard(
              'Utilization Rate',
              '${_systemStats['utilizationRate'] ?? '0.0'}%',
              Icons.analytics,
              AppTheme.statusIssued,
              [
                '${_systemStats['issuedProjectors'] ?? 0} in use',
                '${_systemStats['totalProjectors'] ?? 0} total',
                'Efficient resource usage',
              ],
            ),
            _buildStatCard(
              'Active Transactions',
              _systemStats['activeTransactions']?.toString() ?? '0',
              Icons.swap_horiz,
              AppTheme.warningColor,
              ['Currently issued', 'Pending returns', 'Real-time tracking'],
            ),
          ],
        ),
      ],
    );
  }

  /// Build quick actions
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Scan Projector',
                Icons.qr_code_scanner,
                AppTheme.accentColor,
                () => context.go('/scan-projector'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'Issue Projector',
                Icons.send,
                AppTheme.statusIssued,
                () =>
                    context.go('/scan-projector', extra: {'purpose': 'issue'}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Return Projector',
                Icons.undo,
                AppTheme.statusAvailable,
                () =>
                    context.go('/scan-projector', extra: {'purpose': 'return'}),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'Add Projector',
                Icons.add_circle,
                AppTheme.primaryColor,
                () => context.go('/add-projector'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build recent activity
  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/history'),
              child: Text(
                'View All',
                style: TextStyle(color: AppTheme.accentColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_recentTransactions.isEmpty)
          _buildEmptyState()
        else
          Column(
            children: _recentTransactions.map((transaction) {
              return _buildTransactionCard(transaction);
            }).toList(),
          ),
      ],
    );
  }

  /// Build quick stats cards
  Widget _buildQuickStatsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Stats',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickStatCard(
                'Today\'s Issues',
                _getTodayIssuesCount().toString(),
                Icons.today,
                AppTheme.accentColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickStatCard(
                'Today\'s Returns',
                _getTodayReturnsCount().toString(),
                Icons.undo,
                AppTheme.statusAvailable,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build stat card
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    List<String> details,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
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
          ...details.map(
            (detail) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                detail,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build action button
  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build transaction card
  Widget _buildTransactionCard(ProjectorTransaction transaction) {
    final isIssue = transaction.dateReturned == null;
    final icon = isIssue ? Icons.send : Icons.undo;
    final color = isIssue ? AppTheme.statusIssued : AppTheme.statusAvailable;
    final action = isIssue ? 'Issued to' : 'Returned by';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Projector ${transaction.projectorSerialNumber}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$action ${transaction.lecturerName}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  _formatDate(
                    isIssue
                        ? transaction.dateIssued
                        : transaction.dateReturned!,
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build quick stat card
  Widget _buildQuickStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.textTertiary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 48, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            'No recent activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by issuing or returning projectors to see activity here',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Get greeting based on time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning! 🌅';
    } else if (hour < 17) {
      return 'Good Afternoon! ☀️';
    } else {
      return 'Good Evening! 🌙';
    }
  }

  /// Get today's issues count
  int _getTodayIssuesCount() {
    final today = DateTime.now();
    return _recentTransactions.where((t) {
      return t.status == AppConstants.statusIssued &&
          t.dateIssued.year == today.year &&
          t.dateIssued.month == today.month &&
          t.dateIssued.day == today.day;
    }).length;
  }

  /// Get today's returns count
  int _getTodayReturnsCount() {
    final today = DateTime.now();
    return _recentTransactions.where((t) {
      return t.dateReturned != null &&
          t.dateReturned!.year == today.year &&
          t.dateReturned!.month == today.month &&
          t.dateReturned!.day == today.day;
    }).length;
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
