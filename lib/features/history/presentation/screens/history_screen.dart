import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/models/lecturer.dart';

/// Screen for viewing transaction history
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  List<ProjectorTransaction> _allTransactions = [];
  List<ProjectorTransaction> _filteredTransactions = [];
  Map<String, Lecturer> _lecturersMap = {};
  bool _isLoading = true;

  final List<String> _filterOptions = ['All', 'Active', 'Returned'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load transactions and lecturers data
  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final firestoreService = ref.read(firestoreServiceProvider);

      // Load transactions
      final transactionsStream = firestoreService.getTransactions();
      final transactions = await transactionsStream.first;

      // Load lecturers for detailed information
      final lecturersStream = firestoreService.getLecturers();
      final lecturers = await lecturersStream.first;

      // Create lecturers map for quick lookup
      final lecturersMap = <String, Lecturer>{};
      for (final lecturer in lecturers) {
        lecturersMap[lecturer.id] = lecturer;
      }

      setState(() {
        _allTransactions = transactions;
        _lecturersMap = lecturersMap;
        _filteredTransactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Filter and search transactions
  void _filterTransactions() {
    List<ProjectorTransaction> filtered = _allTransactions;

    // Apply status filter
    if (_selectedFilter != 'All') {
      filtered = filtered.where((transaction) {
        if (_selectedFilter == 'Active') {
          return transaction.isActive;
        } else if (_selectedFilter == 'Returned') {
          return transaction.isCompleted;
        }
        return true;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((transaction) {
        final lecturer = _lecturersMap[transaction.lecturerId];
        return transaction.projectorSerialNumber.toLowerCase().contains(
              query,
            ) ||
            transaction.lecturerName.toLowerCase().contains(query) ||
            (lecturer != null &&
                lecturer.department.toLowerCase().contains(query)) ||
            (lecturer != null &&
                lecturer.email.toLowerCase().contains(query)) ||
            (lecturer != null &&
                lecturer.phoneNumber != null &&
                lecturer.phoneNumber!.toLowerCase().contains(query));
      }).toList();
    }

    setState(() {
      _filteredTransactions = filtered;
    });
  }

  /// Get lecturer details for a transaction
  Lecturer? _getLecturerDetails(String lecturerId) {
    return _lecturersMap[lecturerId];
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadData,
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
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.history, size: 40, color: Colors.white),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction History',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Track all projector movements',
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildStatCard(
                      'Total',
                      _allTransactions.length.toString(),
                      Icons.list_alt,
                      AppTheme.accentColor,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Active',
                      _allTransactions
                          .where((t) => t.isActive)
                          .length
                          .toString(),
                      Icons.pending,
                      AppTheme.warningColor,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Completed',
                      _allTransactions
                          .where((t) => t.isCompleted)
                          .length
                          .toString(),
                      Icons.check_circle,
                      AppTheme.statusAvailable,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filters and Search
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              children: [
                // Filter Chips
                Row(
                  children: _filterOptions.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                          _filterTransactions();
                        },
                        backgroundColor: AppTheme.backgroundColor,
                        selectedColor: AppTheme.accentColor.withValues(
                          alpha: 0.2,
                        ),
                        checkmarkColor: AppTheme.accentColor,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppTheme.accentColor
                              : AppTheme.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Search Field
                TextFormField(
                  controller: _searchController,
                  onChanged: (value) {
                    _searchQuery = value;
                    _filterTransactions();
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Search by projector, lecturer, department, email, or phone...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery = '';
                              _filterTransactions();
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
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
                  ),
                ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.accentColor,
                      ),
                    ),
                  )
                : _filteredTransactions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultPadding,
                    ),
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _filteredTransactions[index];
                      final lecturer = _getLecturerDetails(
                        transaction.lecturerId,
                      );
                      return _buildTransactionCard(transaction, lecturer);
                    },
                  ),
          ),
        ],
      ),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state when no transactions found
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: AppTheme.textTertiary),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'All'
                ? 'No transactions found'
                : 'No transactions yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'All'
                ? 'Try adjusting your search or filters'
                : 'Start by issuing projectors to lecturers',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build transaction card
  Widget _buildTransactionCard(
    ProjectorTransaction transaction,
    Lecturer? lecturer,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: transaction.isActive
              ? AppTheme.warningColor.withValues(alpha: 0.1)
              : AppTheme.statusAvailable.withValues(alpha: 0.1),
          child: Icon(
            transaction.isActive ? Icons.pending : Icons.check_circle,
            color: transaction.isActive
                ? AppTheme.warningColor
                : AppTheme.statusAvailable,
          ),
        ),
        title: Text(
          transaction.projectorSerialNumber,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transaction.lecturerName,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Issued: ${_formatDate(transaction.dateIssued)}',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
          ],
        ),
        trailing: Container(
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
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Projector Information
                _buildInfoSection('Projector Details', Icons.devices, [
                  _buildInfoRow(
                    'Serial Number',
                    transaction.projectorSerialNumber,
                  ),
                  _buildInfoRow('Status', transaction.status),
                  _buildInfoRow(
                    'Date Issued',
                    _formatDate(transaction.dateIssued),
                  ),
                  if (transaction.dateReturned != null)
                    _buildInfoRow(
                      'Date Returned',
                      _formatDate(transaction.dateReturned!),
                    ),
                  _buildInfoRow('Duration', transaction.durationString),
                ]),
                const SizedBox(height: 16),

                // Lecturer Information
                _buildInfoSection('Lecturer Details', Icons.person, [
                  _buildInfoRow('Name', transaction.lecturerName),
                  if (lecturer != null) ...[
                    _buildInfoRow('Department', lecturer.department),
                    _buildInfoRow('Email', lecturer.email),
                    if (lecturer.phoneNumber != null &&
                        lecturer.phoneNumber!.isNotEmpty)
                      _buildInfoRow('Phone', lecturer.phoneNumber!),
                    if (lecturer.employeeId != null &&
                        lecturer.employeeId!.isNotEmpty)
                      _buildInfoRow('Employee ID', lecturer.employeeId!),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build information section
  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.accentColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  /// Build information row
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
