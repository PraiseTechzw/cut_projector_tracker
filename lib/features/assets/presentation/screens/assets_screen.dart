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

  // Pagination variables
  int _currentPage = 1;
  int _itemsPerPage = 15;
  int _totalPages = 1;
  List<Projector> _allProjectors = [];
  List<Projector> _filteredProjectors = [];

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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Asset Register',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
              tooltip: 'Filter & Sort',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More Options',
              onSelected: (value) {
                switch (value) {
                  case 'check_duplicates':
                    _checkForDuplicates();
                    break;
                  case 'cleanup_duplicates':
                    _cleanupDuplicates();
                    break;
                  case 'export_data':
                    _exportAssetData();
                    break;
                  case 'import_data':
                    _importAssetData();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'check_duplicates',
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18),
                      SizedBox(width: 8),
                      Text('Check for Duplicates'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'cleanup_duplicates',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, size: 18),
                      SizedBox(width: 8),
                      Text('Clean Up Duplicates'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_data',
                  child: Row(
                    children: [
                      Icon(Icons.download, size: 18),
                      SizedBox(width: 8),
                      Text('Export Asset Data'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'import_data',
                  child: Row(
                    children: [
                      Icon(Icons.upload, size: 18),
                      SizedBox(width: 8),
                      Text('Import Asset Data'),
                    ],
                  ),
                ),
              ],
            ),
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
                AppTheme.primaryColor.withValues(alpha: 0.6),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 25,
            offset: const Offset(0, 12),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Enhanced Header with better styling
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.15),
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asset Management',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search and filter projectors in the system',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Enhanced Search bar with better styling
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: TextFormField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _currentPage = 1; // Reset to first page when searching
                });
              },
              decoration: InputDecoration(
                labelText: 'Search Projectors',
                hintText:
                    'Search by serial number, model, or last issued to...',
                prefixIcon: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.search,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: AppTheme.errorColor,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        ),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                labelStyle: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                hintStyle: TextStyle(
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Enhanced Filter chips with better styling
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Filter by Status:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusOptions.map((status) {
                      final isSelected = _statusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: FilterChip(
                          label: Text(
                            status,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _statusFilter = selected ? status : 'All';
                              _currentPage =
                                  1; // Reset to first page when filtering
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: AppTheme.primaryColor.withValues(
                            alpha: 0.15,
                          ),
                          checkmarkColor: AppTheme.primaryColor,
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textTertiary.withValues(alpha: 0.2),
                            width: isSelected ? 2 : 1,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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
    _allProjectors = projectors;
    _filteredProjectors = projectors.where((projector) {
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
    _filteredProjectors.sort((a, b) {
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

    // Calculate pagination
    _totalPages = (_filteredProjectors.length / _itemsPerPage).ceil();
    if (_currentPage > _totalPages && _totalPages > 0) {
      _currentPage = _totalPages;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginatedProjectors = _filteredProjectors.sublist(
      startIndex,
      endIndex > _filteredProjectors.length
          ? _filteredProjectors.length
          : endIndex,
    );

    if (_filteredProjectors.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Enhanced Summary Header
        _buildSummaryHeader(),

        // Professional Data Table
        _buildProfessionalTable(paginatedProjectors),

        // Pagination Controls
        if (_totalPages > 1) _buildPaginationControls(),
      ],
    );
  }

  /// Build empty state when no projectors found
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(AppConstants.defaultPadding),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.textTertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.textTertiary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.search_off,
              size: 48,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No projectors found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build enhanced summary header
  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            AppTheme.primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.analytics,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asset Summary',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Showing ${_filteredProjectors.length} of ${_allProjectors.length} projectors',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${_statusFilter == 'All' ? 'All Statuses' : _statusFilter}',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build professional data table
  Widget _buildProfessionalTable(List<Projector> projectors) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 25,
            offset: const Offset(0, 12),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 32,
            dataRowMinHeight: 80,
            dataRowMaxHeight: 80,
            headingRowHeight: 72,
            columns: [
              _buildSortableColumn('Serial Number', 'serialNumber'),
              _buildSortableColumn('Status', 'status'),
              _buildSortableColumn('Last Issued To', 'lastIssuedTo'),
              _buildSortableColumn('Last Issued Date', 'lastIssuedDate'),
              _buildSortableColumn('Last Return Date', 'lastReturnDate'),
              const DataColumn(label: Text('Actions')),
            ],
            rows: projectors.map((projector) {
              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        projector.serialNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  DataCell(_buildStatusChip(projector.status)),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.accentColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        projector.lastIssuedTo ?? 'N/A',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.textSecondary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        projector.lastIssuedDate != null
                            ? _formatDate(projector.lastIssuedDate!)
                            : 'N/A',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.textSecondary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        projector.lastReturnDate != null
                            ? _formatDate(projector.lastReturnDate!)
                            : 'N/A',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  DataCell(_buildActionButtons(projector)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Build pagination controls
  Widget _buildPaginationControls() {
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
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page info
          Text(
            'Page $_currentPage of $_totalPages',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Pagination buttons
          Row(
            children: [
              // Previous page
              IconButton(
                onPressed: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                      }
                    : null,
                icon: Icon(
                  Icons.chevron_left,
                  color: _currentPage > 1
                      ? AppTheme.primaryColor
                      : AppTheme.textTertiary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: _currentPage > 1
                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                      : AppTheme.textTertiary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              // Page numbers
              ...List.generate(_totalPages > 7 ? 7 : _totalPages, (index) {
                int pageNumber;
                if (_totalPages <= 7) {
                  pageNumber = index + 1;
                } else if (_currentPage <= 4) {
                  pageNumber = index + 1;
                } else if (_currentPage >= _totalPages - 3) {
                  pageNumber = _totalPages - 6 + index;
                } else {
                  pageNumber = _currentPage - 3 + index;
                }

                if (pageNumber < 1 || pageNumber > _totalPages)
                  return const SizedBox.shrink();

                final isCurrentPage = pageNumber == _currentPage;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _currentPage = pageNumber;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrentPage
                            ? AppTheme.primaryColor
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrentPage
                              ? AppTheme.primaryColor
                              : AppTheme.primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        pageNumber.toString(),
                        style: TextStyle(
                          color: isCurrentPage
                              ? Colors.white
                              : AppTheme.primaryColor,
                          fontWeight: isCurrentPage
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Next page
              IconButton(
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                      }
                    : null,
                icon: Icon(
                  Icons.chevron_right,
                  color: _currentPage < _totalPages
                      ? AppTheme.primaryColor
                      : AppTheme.textTertiary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: _currentPage < _totalPages
                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                      : AppTheme.textTertiary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),

          // Items per page selector
          Row(
            children: [
              Text(
                'Items per page:',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: DropdownButton<int>(
                  value: _itemsPerPage,
                  underline: const SizedBox.shrink(),
                  items: [10, 15, 25, 50].map((count) {
                    return DropdownMenuItem(
                      value: count,
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _itemsPerPage = value;
                        _currentPage = 1;
                        _totalPages =
                            (_filteredProjectors.length / _itemsPerPage).ceil();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DataColumn _buildSortableColumn(String label, String sortKey) {
    final isSorted = _sortBy == sortKey;
    return DataColumn(
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSorted
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isSorted ? FontWeight.w600 : FontWeight.w500,
                color: isSorted ? AppTheme.primaryColor : AppTheme.textPrimary,
              ),
            ),
            if (isSorted) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ],
        ),
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
        color = AppTheme.statusAvailable;
        icon = Icons.check_circle;
        break;
      case 'Issued':
        color = AppTheme.statusIssued;
        icon = Icons.person;
        break;
      case 'Maintenance':
        color = AppTheme.statusMaintenance;
        icon = Icons.build;
        break;
      default:
        color = AppTheme.textTertiary;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    Projector projector, {
    bool isBottomSheet = false,
  }) {
    if (isBottomSheet) {
      return Column(
        children: [
          // Primary action based on status
          if (projector.status == 'Available')
            _buildBottomSheetButton(
              label: 'Issue Projector',
              icon: Icons.send,
              color: AppTheme.primaryColor,
              onPressed: () {
                Navigator.of(context).pop();
                _quickIssue(projector);
              },
            )
          else if (projector.status == 'Issued')
            _buildBottomSheetButton(
              label: 'Return Projector',
              icon: Icons.keyboard_return,
              color: AppTheme.secondaryColor,
              onPressed: () {
                Navigator.of(context).pop();
                _quickReturn(projector);
              },
            ),

          const SizedBox(height: 12),

          // Secondary actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _editProjector(projector);
                  },
                  icon: Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentColor,
                    side: BorderSide(color: AppTheme.accentColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, size: 18),
                  label: const Text('Close'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.textSecondary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.textTertiary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // View details
          Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                Icons.visibility,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              onPressed: () => _showProjectorDetails(projector),
              tooltip: 'View Details',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),

          // Quick actions based on status
          if (projector.status == 'Available') ...[
            Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.send, size: 18, color: AppTheme.primaryColor),
                onPressed: () => _quickIssue(projector),
                tooltip: 'Quick Issue',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
          ] else if (projector.status == 'Issued') ...[
            Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.keyboard_return,
                  size: 18,
                  color: AppTheme.secondaryColor,
                ),
                onPressed: () => _quickReturn(projector),
                tooltip: 'Quick Return',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
          ],

          // Edit
          Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.edit, size: 18, color: AppTheme.accentColor),
              onPressed: () => _editProjector(projector),
              tooltip: 'Edit Projector',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
        ],
      ),
    );
  }

  /// Build bottom sheet button
  Widget _buildBottomSheetButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.filter_list,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Filter & Sort Options'),
          ],
        ),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status filter
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Filter',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: InputDecoration(
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
                      enabledBorder: OutlineInputBorder(
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _statusFilter = value!;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Sort options
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sort By',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _sortBy,
                    decoration: InputDecoration(
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
                      enabledBorder: OutlineInputBorder(
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                ],
              ),

              const SizedBox(height: 20),

              // Sort direction
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sort, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Sort Direction:',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _sortAscending,
                      onChanged: (value) {
                        setState(() {
                          _sortAscending = value;
                        });
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _sortAscending ? 'Ascending' : 'Descending',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showProjectorDetails(Projector projector) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildProjectorDetailsBottomSheet(projector),
    );
  }

  /// Build enhanced projector details bottom sheet
  Widget _buildProjectorDetailsBottomSheet(Projector projector) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Enhanced Handle Bar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Enhanced Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.primaryColor.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.qr_code,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Projector Details',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    projector.serialNumber,
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close,
                              color: AppTheme.textSecondary,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.backgroundColor,
                              shape: const CircleBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      _buildStatusBadge(projector.status),
                      const SizedBox(height: 24),

                      // Basic Information Card
                      _buildDetailCard(
                        title: 'Basic Information',
                        icon: Icons.info_outline,
                        color: AppTheme.primaryColor,
                        children: [
                          _buildEnhancedDetailRow(
                            'Serial Number',
                            projector.serialNumber,
                            Icons.qr_code,
                          ),
                          if (projector.modelName.isNotEmpty)
                            _buildEnhancedDetailRow(
                              'Model',
                              projector.modelName,
                              Icons.model_training,
                            ),
                          if (projector.projectorName.isNotEmpty)
                            _buildEnhancedDetailRow(
                              'Name',
                              projector.projectorName,
                              Icons.label,
                            ),
                          if (projector.location?.isNotEmpty == true)
                            _buildEnhancedDetailRow(
                              'Location',
                              projector.location!,
                              Icons.location_on,
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Transaction History Card
                      _buildDetailCard(
                        title: 'Transaction History',
                        icon: Icons.history,
                        color: AppTheme.accentColor,
                        children: [
                          _buildEnhancedDetailRow(
                            'Last Issued To',
                            projector.lastIssuedTo ?? 'Never issued',
                            Icons.person,
                          ),
                          _buildEnhancedDetailRow(
                            'Last Issued Date',
                            projector.lastIssuedDate != null
                                ? _formatDate(projector.lastIssuedDate!)
                                : 'N/A',
                            Icons.schedule,
                          ),
                          _buildEnhancedDetailRow(
                            'Last Return Date',
                            projector.lastReturnDate != null
                                ? _formatDate(projector.lastReturnDate!)
                                : 'N/A',
                            Icons.keyboard_return,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // System Information Card
                      _buildDetailCard(
                        title: 'System Information',
                        icon: Icons.settings,
                        color: AppTheme.secondaryColor,
                        children: [
                          _buildEnhancedDetailRow(
                            'Created',
                            _formatDate(projector.createdAt),
                            Icons.add_circle,
                          ),
                          _buildEnhancedDetailRow(
                            'Last Updated',
                            _formatDate(projector.updatedAt),
                            Icons.update,
                          ),
                          if (projector.notes?.isNotEmpty == true)
                            _buildEnhancedDetailRow(
                              'Notes',
                              projector.notes!,
                              Icons.note,
                            ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      _buildActionButtons(projector, isBottomSheet: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build status badge
  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'Available':
        color = AppTheme.statusAvailable;
        icon = Icons.check_circle;
        break;
      case 'Issued':
        color = AppTheme.statusIssued;
        icon = Icons.person;
        break;
      case 'Maintenance':
        color = AppTheme.statusMaintenance;
        icon = Icons.build;
        break;
      default:
        color = AppTheme.textTertiary;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            'Status: $status',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Build detail card
  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  /// Build enhanced detail row
  Widget _buildEnhancedDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.textTertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
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
    context.go('/edit-projector', extra: {'projector': projector});
  }

  void _showAddProjectorDialog() {
    context.go('/add-projector');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Check for duplicate serial numbers in the database
  Future<void> _checkForDuplicates() async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final duplicates = await firestoreService.findDuplicateSerialNumbers();

      if (mounted) {
        if (duplicates.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No duplicate serial numbers found! Database is clean.',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.statusAvailable,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
            ),
          );
        } else {
          // Group duplicates by serial number for better display
          final Map<String, List<Projector>> groupedDuplicates = {};
          for (final projector in duplicates) {
            final serial = projector.serialNumber.toUpperCase();
            groupedDuplicates.putIfAbsent(serial, () => []).add(projector);
          }

          _showDuplicatesDialog(groupedDuplicates);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error checking for duplicates: $e')),
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

  /// Clean up duplicate projectors
  Future<void> _cleanupDuplicates() async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final duplicates = await firestoreService.findDuplicateSerialNumbers();

      if (duplicates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No duplicates to clean up! Database is already clean.',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.statusAvailable,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
            ),
          );
        }
        return;
      }

      // Show confirmation dialog
      if (mounted) {
        final shouldCleanup = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: AppTheme.warningColor),
                const SizedBox(width: 12),
                const Text('Clean Up Duplicates'),
              ],
            ),
            content: Text(
              'Found ${duplicates.length} projectors with duplicate serial numbers. '
              'This will keep the most recent projector for each serial number and delete the older ones. '
              'This action cannot be undone.\n\n'
              'Are you sure you want to proceed?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Clean Up'),
              ),
            ],
          ),
        );

        if (shouldCleanup == true) {
          await firestoreService.removeDuplicateProjectors();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Duplicates cleaned up successfully!'),
                    ),
                  ],
                ),
                backgroundColor: AppTheme.statusAvailable,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius,
                  ),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error cleaning up duplicates: $e')),
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

  /// Export asset data to CSV
  Future<void> _exportAssetData() async {
    try {
      // TODO: Implement CSV export functionality
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Export functionality coming soon!')),
            ],
          ),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error exporting data: $e')),
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

  /// Import asset data from CSV
  Future<void> _importAssetData() async {
    try {
      // TODO: Implement CSV import functionality
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Import functionality coming soon!')),
            ],
          ),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error importing data: $e')),
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

  /// Show duplicates dialog with details
  void _showDuplicatesDialog(Map<String, List<Projector>> groupedDuplicates) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppTheme.warningColor),
            const SizedBox(width: 12),
            Text('Found ${groupedDuplicates.length} Duplicate Serial Numbers'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The following serial numbers have multiple projectors:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ...groupedDuplicates.entries.map((entry) {
                final serial = entry.key;
                final projectors = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Serial: $serial (${projectors.length} duplicates)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warningColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...projectors.map(
                      (projector) => Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4),
                        child: Text(
                          '• ${projector.projectorName} (${projector.modelName}) - Created: ${_formatDate(projector.createdAt)}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
              const SizedBox(height: 8),
              Text(
                'Use "Clean Up Duplicates" to automatically remove older duplicates.',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
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
              _cleanupDuplicates();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clean Up Now'),
          ),
        ],
      ),
    );
  }
}
