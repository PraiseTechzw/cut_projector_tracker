import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/projector.dart';
import '../../../../shared/models/lecturer.dart';

/// Projector issuance screen for assigning projectors to lecturers
class IssuanceScreen extends ConsumerStatefulWidget {
  final Projector? projector; // Pre-selected projector from scanning

  const IssuanceScreen({super.key, this.projector});

  @override
  ConsumerState<IssuanceScreen> createState() => _IssuanceScreenState();
}

class _IssuanceScreenState extends ConsumerState<IssuanceScreen>
    with TickerProviderStateMixin {
  Projector? _selectedProjector;
  Lecturer? _selectedLecturer;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Form controllers
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();

  // Confetti controller
  late ConfettiController _confettiController;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedProjector = widget.projector;
    _setupAnimations();
    _setupConfetti();
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

  void _setupConfetti() {
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    _confettiController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _scanProjector() async {
    final result = await context.push(
      '/scan-projector',
      extra: {'purpose': 'issue'},
    );
    if (result != null && result is Projector) {
      setState(() {
        _selectedProjector = result;
        _errorMessage = null;
      });
    }
  }

  Future<void> _searchLecturers(String query) async {
    if (query.length < 2) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final lecturers = await firestoreService.searchLecturers(query);
      // Update UI with search results
      _showLecturerSearchResults(lecturers);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching lecturers: $e';
      });
    }
  }

  void _showLecturerSearchResults(List<Lecturer> lecturers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Lecturer',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: lecturers.isEmpty
                  ? const Center(child: Text('No lecturers found'))
                  : ListView.builder(
                      itemCount: lecturers.length,
                      itemBuilder: (context, index) {
                        final lecturer = lecturers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            child: Text(
                              lecturer.name
                                  .split(' ')
                                  .map((e) => e[0])
                                  .join(''),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(lecturer.name),
                          subtitle: Text(
                            '${lecturer.department} • ${lecturer.employeeId}',
                          ),
                          onTap: () {
                            setState(() {
                              _selectedLecturer = lecturer;
                              _errorMessage = null;
                            });
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _issueProjector() async {
    if (_selectedProjector == null || _selectedLecturer == null) {
      setState(() {
        _errorMessage = 'Please select both a projector and a lecturer';
      });
      return;
    }

    if (_selectedProjector!.status != 'Available') {
      setState(() {
        _errorMessage = 'This projector is not available for issue';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Issue projector (updates projector status and creates transaction)
      await firestoreService.issueProjector(
        projectorId: _selectedProjector!.id,
        lecturerId: _selectedLecturer!.id,
        projectorSerialNumber: _selectedProjector!.serialNumber,
        lecturerName: _selectedLecturer!.name,
      );

      setState(() {
        _isLoading = false;
        _successMessage = 'Projector issued successfully!';
      });

      // Play confetti
      _confettiController.play();

      // Show success dialog
      _showSuccessDialog();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error issuing projector: $e';
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            const Text('Projector Issued'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Projector: ${_selectedProjector!.serialNumber}'),
            Text('Issued To: ${_selectedLecturer!.name}'),
            Text('Department: ${_selectedLecturer!.department}'),
            Text('Date: ${_formatDate(DateTime.now())}'),
            if (_notesController.text.isNotEmpty)
              Text('Notes: ${_notesController.text}'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetForm();
            },
            child: const Text('Issue Another'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/home');
            },
            child: const Text('Go to Home'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _selectedProjector = null;
      _selectedLecturer = null;
      _notesController.clear();
      _searchController.clear();
      _errorMessage = null;
      _successMessage = null;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Issue Projector'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetForm,
            tooltip: 'Reset Form',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
              colors: [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
                Colors.orange,
                Colors.pink,
                Colors.purple,
                Colors.teal,
              ],
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.largePadding),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      _buildHeader(),

                      const SizedBox(height: 32),

                      // Projector Selection
                      _buildProjectorSelection(),

                      const SizedBox(height: 24),

                      // Lecturer Selection
                      _buildLecturerSelection(),

                      const SizedBox(height: 24),

                      // Notes
                      _buildNotesSection(),

                      const SizedBox(height: 32),

                      // Error/Success Messages
                      if (_errorMessage != null) _buildErrorMessage(),
                      if (_successMessage != null) _buildSuccessMessage(),

                      const SizedBox(height: 24),

                      // Issue Button
                      _buildIssueButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.secondaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.video_camera_front,
            size: 48,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Issue Projector',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Assign a projector to a lecturer for their use',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProjectorSelection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.video_camera_front, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Projector Selection',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedProjector != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Selected Projector',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Serial: ${_selectedProjector!.serialNumber}'),
                    Text('Status: ${_selectedProjector!.status}'),
                    if (_selectedProjector!.lastIssuedTo != null)
                      Text(
                        'Last Issued To: ${_selectedProjector!.lastIssuedTo}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _scanProjector,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Change Projector'),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _scanProjector,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scan Projector'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLecturerSelection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Lecturer Selection',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedLecturer != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Selected Lecturer',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${_selectedLecturer!.name}'),
                    Text('Department: ${_selectedLecturer!.department}'),
                    Text('Employee ID: ${_selectedLecturer!.employeeId}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedLecturer = null;
                  });
                },
                icon: const Icon(Icons.change_circle),
                label: const Text('Change Lecturer'),
              ),
            ] else ...[
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Lecturers',
                  hintText: 'Enter name, department, or employee ID',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _searchLecturers,
              ),
              const SizedBox(height: 8),
              Text(
                'Type at least 2 characters to search',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Additional Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Enter any additional notes about this issue...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.errorColor),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.errorColor),
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _successMessage!,
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueButton() {
    final canIssue =
        _selectedProjector != null &&
        _selectedLecturer != null &&
        _selectedProjector!.status == 'Available';

    return ElevatedButton.icon(
      onPressed: canIssue && !_isLoading ? _issueProjector : null,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.send),
      label: Text(_isLoading ? 'Issuing...' : 'Issue Projector'),
      style: ElevatedButton.styleFrom(
        backgroundColor: canIssue
            ? AppTheme.primaryColor
            : AppTheme.textTertiary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
    );
  }
}
