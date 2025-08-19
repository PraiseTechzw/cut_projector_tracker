import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';

/// Asset register screen showing all projectors with their status
class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _sortBy = 'serialNumber';
  bool _sortAscending = true;

  final List<String> _statusOptions = [
    'All',
    'Available',
    'Issued',
    'Maintenance',
  ];

  @override
  Widget build(BuildContext context) {
    final projectorsStream = ref.watch(projectorsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Asset Register'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter & Sort',
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.8),
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
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                  AppTheme.backgroundColor,
                ],
              ),
            ),
          ),

          Column(
            children: [
              // Search and filter bar
              _buildSearchAndFilterBar(),

              // Projectors table
              Expanded(
                child: projectorsStream.when(
                  data: (projectors) => _buildProjectorsTable(projectors),
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading projectors',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: AppTheme.errorColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProjectorDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Projector'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      margin: const EdgeInsets.all(AppConstants.defaultPadding),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          // Enhanced Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory,
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
                      'Asset Management',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Search and filter projectors in the system',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Enhanced Search bar
          TextFormField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              labelText: 'Search Projectors',
              hintText: 'Search by serial number, model, or last issued to...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
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
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Enhanced Filter chips
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by Status:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statusOptions.map((status) {
                    final isSelected = _statusFilter == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(status),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _statusFilter = selected ? status : 'All';
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                        checkmarkColor: AppTheme.primaryColor,
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textTertiary.withValues(alpha: 0.3),
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectorsTable(List<Projector> projectors) {
    // Apply filters and search
    var filteredProjectors = projectors.where((projector) {
      // Status filter
      if (_statusFilter != 'All' && projector.status != _statusFilter) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return projector.serialNumber.toLowerCase().contains(query) ||
            (projector.lastIssuedTo?.toLowerCase().contains(query) ?? false);
      }

      return true;
    }).toList();

    // Apply sorting
    filteredProjectors.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'serialNumber':
          comparison = a.serialNumber.compareTo(b.serialNumber);
          break;
        case 'status':
          comparison = a.status.compareTo(b.status);
          break;

        case 'lastIssuedDate':
          if (a.lastIssuedDate == null && b.lastIssuedDate == null) {
            comparison = 0;
          } else if (a.lastIssuedDate == null) {
            comparison = -1;
          } else if (b.lastIssuedDate == null) {
            comparison = 1;
          } else {
            comparison = a.lastIssuedDate!.compareTo(b.lastIssuedDate!);
          }
          break;
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });

    if (filteredProjectors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No projectors found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          _buildSortableColumn('Serial Number', 'serialNumber'),
          _buildSortableColumn('Status', 'status'),
          _buildSortableColumn('Last Issued To', 'lastIssuedTo'),
          _buildSortableColumn('Last Issued Date', 'lastIssuedDate'),
          _buildSortableColumn('Last Return Date', 'lastReturnDate'),
          const DataColumn(label: Text('Actions')),
        ],
        rows: filteredProjectors.map((projector) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  projector.serialNumber,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DataCell(_buildStatusChip(projector.status)),
              DataCell(Text(projector.lastIssuedTo ?? 'N/A')),
              DataCell(
                Text(
                  projector.lastIssuedDate != null
                      ? _formatDate(projector.lastIssuedDate!)
                      : 'N/A',
                ),
              ),
              DataCell(
                Text(
                  projector.lastReturnDate != null
                      ? _formatDate(projector.lastReturnDate!)
                      : 'N/A',
                ),
              ),
              DataCell(_buildActionButtons(projector)),
            ],
          );
        }).toList(),
      ),
    );
  }

  DataColumn _buildSortableColumn(String label, String sortKey) {
    final isSorted = _sortBy == sortKey;
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isSorted) ...[
            const SizedBox(width: 4),
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: AppTheme.primaryColor,
            ),
          ],
        ],
      ),
      onSort: (columnIndex, ascending) {
        setState(() {
          _sortBy = sortKey;
          _sortAscending = ascending;
        });
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'Available':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'Issued':
        color = Colors.orange;
        icon = Icons.person;
        break;
      case 'Maintenance':
        color = Colors.red;
        icon = Icons.build;
        break;
      default:
        color = AppTheme.textTertiary;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Projector projector) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // View details
        IconButton(
          icon: const Icon(Icons.visibility, size: 20),
          onPressed: () => _showProjectorDetails(projector),
          tooltip: 'View Details',
        ),

        // Quick actions based on status
        if (projector.status == 'Available') ...[
          IconButton(
            icon: const Icon(Icons.send, size: 20),
            onPressed: () => _quickIssue(projector),
            tooltip: 'Quick Issue',
            color: AppTheme.primaryColor,
          ),
        ] else if (projector.status == 'Issued') ...[
          IconButton(
            icon: const Icon(Icons.keyboard_return, size: 20),
            onPressed: () => _quickReturn(projector),
            tooltip: 'Quick Return',
            color: AppTheme.secondaryColor,
          ),
        ],

        // Edit
        IconButton(
          icon: const Icon(Icons.edit, size: 20),
          onPressed: () => _editProjector(projector),
          tooltip: 'Edit Projector',
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter & Sort Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status filter
            DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Status Filter',
                border: OutlineInputBorder(),
              ),
              items: _statusOptions.map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _statusFilter = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            // Sort options
            DropdownButtonFormField<String>(
              value: _sortBy,
              decoration: const InputDecoration(
                labelText: 'Sort By',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'serialNumber',
                  child: Text('Serial Number'),
                ),
                DropdownMenuItem(value: 'status', child: Text('Status')),
                DropdownMenuItem(
                  value: 'lastIssuedDate',
                  child: Text('Last Issued Date'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            // Sort direction
            Row(
              children: [
                Text('Sort Direction: '),
                Switch(
                  value: _sortAscending,
                  onChanged: (value) {
                    setState(() {
                      _sortAscending = value;
                    });
                  },
                ),
                Text(_sortAscending ? 'Ascending' : 'Descending'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showProjectorDetails(Projector projector) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Projector Details - ${projector.serialNumber}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Serial Number', projector.serialNumber),
              _buildDetailRow('Status', projector.status),
              _buildDetailRow(
                'Last Issued To',
                projector.lastIssuedTo ?? 'N/A',
              ),
              _buildDetailRow(
                'Last Issued Date',
                projector.lastIssuedDate != null
                    ? _formatDate(projector.lastIssuedDate!)
                    : 'N/A',
              ),
              _buildDetailRow(
                'Last Return Date',
                projector.lastReturnDate != null
                    ? _formatDate(projector.lastReturnDate!)
                    : 'N/A',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _editProjector(projector);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _quickIssue(Projector projector) {
    context.go('/issue-projector', extra: {'projector': projector});
  }

  void _quickReturn(Projector projector) {
    context.go('/return-projector', extra: {'projector': projector});
  }

  void _editProjector(Projector projector) {
    // TODO: Implement edit projector functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Edit functionality coming soon for ${projector.serialNumber}',
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _showAddProjectorDialog() {
    // TODO: Implement add projector functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add projector functionality coming soon'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
