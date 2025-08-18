import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/transaction.dart';

/// Screen for exporting system data in various formats
class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  bool _isLoading = false;
  bool _isExporting = false;
  String _selectedDataType = 'projectors';
  String _selectedFormat = 'csv';
  String _selectedDateRange = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  
  final List<String> _dataTypes = [
    'projectors',
    'lecturers',
    'transactions',
    'active_transactions',
    'completed_transactions',
  ];
  
  final List<String> _formats = ['csv', 'json'];
  final List<String> _dateRanges = [
    'all',
    'today',
    'this_week',
    'this_month',
    'last_month',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load data for preview
  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Data will be loaded when export is requested
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Export data based on selected options
  Future<void> _exportData() async {
    if (_selectedDataType.isEmpty || _selectedFormat.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select data type and format'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      List<Map<String, dynamic>> data = [];
      String fileName = '';

      // Load data based on selection
      switch (_selectedDataType) {
        case 'projectors':
          final projectorsStream = firestoreService.getProjectors();
          final projectors = await projectorsStream.first;
          data = projectors.map((p) => p.toFirestore()).toList();
          fileName = 'projectors_${_getTimestamp()}';
          break;
        
        case 'lecturers':
          final lecturersStream = firestoreService.getLecturers();
          final lecturers = await lecturersStream.first;
          data = lecturers.map((l) => l.toFirestore()).toList();
          fileName = 'lecturers_${_getTimestamp()}';
          break;
        
        case 'transactions':
          final transactionsStream = firestoreService.getTransactions();
          final transactions = await transactionsStream.first;
          data = _filterTransactionsByDate(transactions)
              .map((t) => t.toFirestore())
              .toList();
          fileName = 'transactions_${_getTimestamp()}';
          break;
        
        case 'active_transactions':
          final activeTransactionsStream = firestoreService.getActiveTransactions();
          final activeTransactions = await activeTransactionsStream.first;
          data = _filterTransactionsByDate(activeTransactions)
              .map((t) => t.toFirestore())
              .toList();
          fileName = 'active_transactions_${_getTimestamp()}';
          break;
        
        case 'completed_transactions':
          final transactionsStream = firestoreService.getTransactions();
          final transactions = await transactionsStream.first;
          final completedTransactions = transactions.where((t) => t.isCompleted).toList();
          data = _filterTransactionsByDate(completedTransactions)
              .map((t) => t.toFirestore())
              .toList();
          fileName = 'completed_transactions_${_getTimestamp()}';
          break;
      }

      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No data found for the selected criteria'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return;
      }

      // Export based on format
      if (_selectedFormat == 'csv') {
        await _exportToCSV(data, fileName);
      } else if (_selectedFormat == 'json') {
        await _exportToJSON(data, fileName);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data exported successfully as $fileName.$_selectedFormat'),
            backgroundColor: Colors.green,
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
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  /// Filter transactions by selected date range
  List<ProjectorTransaction> _filterTransactionsByDate(List<ProjectorTransaction> transactions) {
    if (_selectedDateRange == 'all') return transactions;

    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedDateRange) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'this_week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'this_month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'last_month':
        startDate = DateTime(now.year, now.month - 1, 1);
        break;
      case 'custom':
        if (_startDate != null && _endDate != null) {
          return transactions.where((t) => 
            t.dateIssued.isAfter(_startDate!) && 
            t.dateIssued.isBefore(_endDate!.add(const Duration(days: 1)))
          ).toList();
        }
        return transactions;
      default:
        return transactions;
    }

    return transactions.where((t) => t.dateIssued.isAfter(startDate)).toList();
  }

  /// Export data to CSV format
  Future<void> _exportToCSV(List<Map<String, dynamic>> data, String fileName) async {
    if (data.isEmpty) return;

    // Get headers from first data item
    final headers = data.first.keys.toList();
    
    // Convert data to CSV format
    final csvData = [
      headers, // Header row
      ...data.map((row) => headers.map((header) => row[header]?.toString() ?? '').toList()),
    ];

    final csvContent = const ListToCsvConverter().convert(csvData);

    // Save to file
    await _saveToFile('$fileName.csv', csvContent);
  }

  /// Export data to JSON format
  Future<void> _exportToJSON(List<Map<String, dynamic>> data, String fileName) async {
    if (data.isEmpty) return;

    // Convert to JSON string with proper formatting
    final jsonContent = data.toString(); // Simple conversion for now
    
    // Save to file
    await _saveToFile('$fileName.json', jsonContent);
  }

  /// Save content to file
  Future<void> _saveToFile(String fileName, String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      
      // Show success message with file path
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved to: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Copy Path',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: file.path));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('File path copied to clipboard'),
                    backgroundColor: AppTheme.accentColor,
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      throw 'Failed to save file: $e';
    }
  }

  /// Get timestamp for filename
  String _getTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  /// Show date picker for custom range
  Future<void> _showDatePicker(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? DateTime.now().subtract(const Duration(days: 30)) : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Export Data'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Export Options
                  _buildExportOptions(),
                  const SizedBox(height: 24),

                  // Date Range Selection
                  _buildDateRangeSelection(),
                  const SizedBox(height: 24),

                  // Export Button
                  _buildExportButton(),
                  const SizedBox(height: 24),

                  // Export History (placeholder)
                  _buildExportHistory(),
                ],
              ),
            ),
    );
  }

  /// Build header section
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.largePadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentColor,
            AppTheme.accentColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.download,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Export System Data',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Export data in various formats for analysis and backup',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build export options
  Widget _buildExportOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Export Options',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        
        // Data Type Selection
        _buildSelectionCard(
          'Data Type',
          'Select what data to export',
          Icons.data_usage,
          _selectedDataType,
          _dataTypes,
          (value) {
            setState(() {
              _selectedDataType = value;
            });
          },
        ),
        const SizedBox(height: 16),

        // Format Selection
        _buildSelectionCard(
          'Export Format',
          'Choose the file format',
          Icons.file_download,
          _selectedFormat,
          _formats,
          (value) {
            setState(() {
              _selectedFormat = value;
            });
          },
        ),
      ],
    );
  }

  /// Build selection card
  Widget _buildSelectionCard(
    String title,
    String subtitle,
    IconData icon,
    String selectedValue,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: options.map((option) {
              final isSelected = selectedValue == option;
              return FilterChip(
                label: Text(option.replaceAll('_', ' ').toUpperCase()),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    onChanged(option);
                  }
                },
                backgroundColor: AppTheme.backgroundColor,
                selectedColor: AppTheme.accentColor.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.accentColor,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.accentColor : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Build date range selection
  Widget _buildDateRangeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Range',
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Date Range Options
              Wrap(
                spacing: 8,
                children: _dateRanges.map((range) {
                  final isSelected = _selectedDateRange == range;
                  return FilterChip(
                    label: Text(range.replaceAll('_', ' ').toUpperCase()),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedDateRange = range;
                          if (range != 'custom') {
                            _startDate = null;
                            _endDate = null;
                          }
                        });
                      }
                    },
                    backgroundColor: AppTheme.backgroundColor,
                    selectedColor: AppTheme.accentColor.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.accentColor,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.accentColor : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),

              // Custom Date Range
              if (_selectedDateRange == 'custom') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField(
                        'Start Date',
                        _startDate,
                        () => _showDatePicker(true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDateField(
                        'End Date',
                        _endDate,
                        () => _showDatePicker(false),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Build date field
  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
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
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.textTertiary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Select date',
                    style: TextStyle(
                      color: date != null ? AppTheme.textPrimary : AppTheme.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build export button
  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: AppConstants.buttonHeight,
      child: ElevatedButton(
        onPressed: _isExporting ? null : _exportData,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
        ),
        child: _isExporting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Exporting...'),
                ],
              )
            : const Text(
                'Export Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  /// Build export history (placeholder)
  Widget _buildExportHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Export History',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
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
                  'Export history coming soon',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track your previous exports and download them again',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
