import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/models/projector.dart';
import '../../../../shared/models/lecturer.dart';

/// Enhanced screen for viewing transaction history with filtering and export
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _selectedStatus = 'All';
  String _selectedProjector = 'All';
  String _selectedLecturer = 'All';
  DateTimeRange? _selectedDateRange;
  List<ProjectorTransaction> _allTransactions = [];
  List<ProjectorTransaction> _filteredTransactions = [];
  List<Projector> _allProjectors = [];
  List<Lecturer> _allLecturers = [];
  bool _isLoading = true;
  bool _isExporting = false;

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

  /// Load all data
  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final firestoreService = ref.read(firestoreServiceProvider);

      // Load all streams
      final transactionsStream = firestoreService.getTransactions();
      final projectorsStream = firestoreService.getProjectors();
      final lecturersStream = firestoreService.getLecturers();

      // Get first values
      final transactions = await transactionsStream.first;
      final projectors = await projectorsStream.first;
      final lecturers = await lecturersStream.first;

      setState(() {
        _allTransactions = transactions;
        _allProjectors = projectors;
        _allLecturers = lecturers;
        _filteredTransactions = transactions;
        _isLoading = false;
      });

      _applyFilters();
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

  /// Apply all filters
  void _applyFilters() {
    List<ProjectorTransaction> filtered = _allTransactions;

    // Status filter
    if (_selectedStatus != 'All') {
      filtered = filtered.where((t) => t.status == _selectedStatus).toList();
    }

    // Projector filter
    if (_selectedProjector != 'All') {
      filtered = filtered
          .where((t) => t.projectorSerialNumber == _selectedProjector)
          .toList();
    }

    // Lecturer filter
    if (_selectedLecturer != 'All') {
      filtered = filtered
          .where((t) => t.lecturerName == _selectedLecturer)
          .toList();
    }

    // Date range filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((t) {
        final issueDate = t.dateIssued;
        return issueDate.isAfter(
              _selectedDateRange!.start.subtract(const Duration(days: 1)),
            ) &&
            issueDate.isBefore(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            );
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        return t.projectorSerialNumber.toLowerCase().contains(query) ||
            t.lecturerName.toLowerCase().contains(query) ||
            t.id.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredTransactions = filtered;
    });
  }

  /// Export to CSV
  Future<void> _exportToCSV() async {
    if (_filteredTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      // Prepare CSV data
      final csvData = [
        [
          'Transaction ID',
          'Projector Serial',
          'Lecturer Name',
          'Status',
          'Date Issued',
          'Date Returned',
          'Duration (Days)',
          'Created At',
        ],
        ..._filteredTransactions.map(
          (t) => [
            t.id,
            t.projectorSerialNumber,
            t.lecturerName,
            t.status,
            DateFormat('yyyy-MM-dd HH:mm').format(t.dateIssued),
            t.dateReturned != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(t.dateReturned!)
                : 'N/A',
            t.dateReturned != null
                ? t.dateReturned!.difference(t.dateIssued).inDays.toString()
                : 'Active',
            DateFormat('yyyy-MM-dd HH:mm').format(t.createdAt),
          ],
        ),
      ];

      // Convert to CSV
      final csvString = const ListToCsvConverter().convert(csvData);

      // Get directory and create file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'projector_history_$timestamp.csv';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(csvString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('CSV exported successfully to: $fileName'),
                ),
              ],
            ),
            backgroundColor: AppTheme.statusAvailable,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () {
                // TODO: Implement file opening
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('File saved to app documents directory'),
                    backgroundColor: AppTheme.accentColor,
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  /// Select date range
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceColor,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _applyFilters();
    }
  }

  /// Clear date range
  void _clearDateRange() {
    setState(() {
      _selectedDateRange = null;
    });
    _applyFilters();
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
          IconButton(
            onPressed: _isExporting ? null : _exportToCSV,
            icon: _isExporting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: 'Export to CSV',
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
                        Icons.history,
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
                            'Transaction History',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            'View and analyze all projector transactions',
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
                Row(
                  children: [
                    _buildStatCard(
                      'Total',
                      _allTransactions.length.toString(),
                      Icons.list,
                      Colors.white,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Filtered',
                      _filteredTransactions.length.toString(),
                      Icons.filter_list,
                      Colors.white,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Active',
                      _allTransactions
                          .where(
                            (t) => t.status == AppConstants.transactionActive,
                          )
                          .length
                          .toString(),
                      Icons.pending,
                      Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filters Section
          Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              children: [
                // Search Bar
                TextFormField(
                  controller: _searchController,
                  onChanged: (value) {
                    _searchQuery = value;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by projector, lecturer, or ID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery = '';
                              _applyFilters();
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
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Filter Row 1
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        'Status',
                        _selectedStatus,
                        [
                          'All',
                          AppConstants.transactionActive,
                          AppConstants.transactionReturned,
                        ],
                        (value) {
                          setState(() {
                            _selectedStatus = value!;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        'Projector',
                        _selectedProjector,
                        ['All', ..._allProjectors.map((p) => p.serialNumber)],
                        (value) {
                          setState(() {
                            _selectedProjector = value!;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filter Row 2
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        'Lecturer',
                        _selectedLecturer,
                        ['All', ..._allLecturers.map((l) => l.name)],
                        (value) {
                          setState(() {
                            _selectedLecturer = value!;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDateRangeFilter()),
                  ],
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
                        AppTheme.primaryColor,
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
                      return _buildTransactionCard(transaction);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Build stat card
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
                fontSize: 20,
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

  /// Build filter dropdown
  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 14,
                  color: option == 'All'
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// Build date range filter
  Widget _buildDateRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Range',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.date_range),
                label: Text(
                  _selectedDateRange != null
                      ? '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}'
                      : 'Select Range',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            if (_selectedDateRange != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: _clearDateRange,
                icon: const Icon(Icons.clear, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.errorColor,
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Build transaction card
  Widget _buildTransactionCard(ProjectorTransaction transaction) {
    final isActive = transaction.status == AppConstants.transactionActive;
    final icon = isActive ? Icons.pending : Icons.check_circle;
    final color = isActive ? AppTheme.warningColor : AppTheme.statusAvailable;
    final statusText = isActive ? 'Active' : 'Returned';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction ${transaction.id.substring(0, 8)}...',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        statusText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Details
            _buildDetailRow(
              'Projector',
              transaction.projectorSerialNumber,
              Icons.qr_code,
            ),
            _buildDetailRow('Lecturer', transaction.lecturerName, Icons.person),
            _buildDetailRow(
              'Issued',
              _formatDate(transaction.dateIssued),
              Icons.send,
            ),
            if (transaction.dateReturned != null)
              _buildDetailRow(
                'Returned',
                _formatDate(transaction.dateReturned!),
                Icons.undo,
              ),
            if (transaction.dateReturned != null) ...[
              _buildDetailRow(
                'Duration',
                '${transaction.dateReturned!.difference(transaction.dateIssued).inDays} days',
                Icons.timer,
              ),
            ],
            _buildDetailRow(
              'Created',
              _formatDate(transaction.createdAt),
              Icons.add_circle,
            ),
          ],
        ),
      ),
    );
  }

  /// Build detail row
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
            width: 80,
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

  /// Build empty state
  Widget _buildEmptyState() {
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
                Icons.history,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty ||
                      _selectedStatus != 'All' ||
                      _selectedProjector != 'All' ||
                      _selectedLecturer != 'All' ||
                      _selectedDateRange != null
                  ? 'No transactions found'
                  : 'No transactions yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ||
                      _selectedStatus != 'All' ||
                      _selectedProjector != 'All' ||
                      _selectedLecturer != 'All' ||
                      _selectedDateRange != null
                  ? 'Try adjusting your filters or search criteria'
                  : 'Start by issuing projectors to see transaction history here',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty ||
                _selectedStatus != 'All' ||
                _selectedProjector != 'All' ||
                _selectedLecturer != 'All' ||
                _selectedDateRange != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedStatus = 'All';
                    _selectedProjector = 'All';
                    _selectedLecturer = 'All';
                    _selectedDateRange = null;
                  });
                  _searchController.clear();
                  _applyFilters();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear All Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }
}
