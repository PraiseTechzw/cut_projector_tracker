import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../features/assets/presentation/screens/assets_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/issuance/presentation/screens/issuance_screen.dart';
import '../../features/returns/presentation/screens/returns_screen.dart';
import '../../features/scanning/presentation/screens/scanning_screen.dart';

/// Main navigation widget with bottom navigation bar
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ScanningScreen(),
    const IssuanceScreen(),
    const ReturnsScreen(),
    const AssetsScreen(),
    const HistoryScreen(),
  ];

  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.qr_code_scanner),
      label: 'Scan',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.add_circle_outline),
      label: 'Issue',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.undo),
      label: 'Return',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.inventory),
      label: 'Assets',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.history),
      label: 'History',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: _navItems,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondary,
        backgroundColor: AppTheme.backgroundColor,
        elevation: 8,
      ),
    );
  }

  /// Get app bar title based on current tab
  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Scan Projector';
      case 1:
        return 'Issue Projector';
      case 2:
        return 'Return Projector';
      case 3:
        return 'Asset Register';
      case 4:
        return 'Transaction History';
      default:
        return AppConstants.appName;
    }
  }

  /// Handle user logout
  Future<void> _handleLogout() async {
    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      await authService.signOut();
      
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
