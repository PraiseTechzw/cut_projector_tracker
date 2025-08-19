import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/presentation/screens/signin_screen.dart';
import 'features/auth/presentation/screens/signup_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/welcome_screen.dart';
import 'features/auth/presentation/widgets/auth_guard.dart';
import 'shared/widgets/main_navigation.dart';
import 'features/scanning/presentation/screens/scanning_screen.dart';
import 'features/returns/presentation/screens/returns_screen.dart';
import 'features/returns/presentation/screens/return_projector_screen.dart';
import 'features/assets/presentation/screens/add_projector_screen.dart';
import 'features/assets/presentation/screens/edit_projector_screen.dart';
import 'features/lecturers/presentation/screens/add_lecturer_screen.dart';
import 'features/lecturers/presentation/screens/edit_lecturer_screen.dart';
import 'features/lecturers/presentation/screens/lecturers_screen.dart';
import 'shared/models/projector.dart';
import 'shared/models/lecturer.dart';
import 'features/issuance/presentation/screens/issue_projector_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: CutProjectorTrackerApp()));
}

class CutProjectorTrackerApp extends ConsumerWidget {
  const CutProjectorTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    // Public routes (no auth required)
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/signin',
      builder: (context, state) =>
          const AuthGuard(requireAuth: false, child: SignInScreen()),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) =>
          const AuthGuard(requireAuth: false, child: SignUpScreen()),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final userName = extra?['userName'] ?? 'User';
        final isNewUser = extra?['isNewUser'] ?? false;
        return WelcomeScreen(userName: userName, isNewUser: isNewUser);
      },
    ),
    GoRoute(
      path: '/scan-projector',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final purpose = extra?['purpose'] as String?;
        return ScanningScreen(purpose: purpose);
      },
    ),
    GoRoute(
      path: '/issue-projector',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final projector = extra?['projector'] as Projector?;
        // Allow null projector for main navigation tab usage
        return IssueProjectorScreen(projector: projector);
      },
    ),
    GoRoute(
      path: '/return-projector',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final projector = extra?['projector'] as Projector?;
        if (projector != null) {
          // If projector is provided, show the detailed return screen
          return ReturnProjectorScreen(projector: projector);
        } else {
          // If no projector, show the main returns screen
          return const ReturnsScreen();
        }
      },
    ),
    GoRoute(
      path: '/add-projector',
      builder: (context, state) =>
          const AuthGuard(requireAuth: true, child: AddProjectorScreen()),
    ),
    GoRoute(
      path: '/edit-projector',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final projector = extra?['projector'] as Projector?;
        if (projector == null) {
          return const _ErrorScreen(error: 'Projector not found');
        }
        return AuthGuard(
          requireAuth: true,
          child: EditProjectorScreen(projector: projector),
        );
      },
    ),
    GoRoute(
      path: '/add-lecturer',
      builder: (context, state) =>
          const AuthGuard(requireAuth: true, child: AddLecturerScreen()),
    ),
    GoRoute(
      path: '/edit-lecturer',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final lecturer = extra?['lecturer'] as Lecturer?;
        if (lecturer == null) {
          return const _ErrorScreen(error: 'Lecturer not found');
        }
        return AuthGuard(
          requireAuth: true,
          child: EditLecturerScreen(lecturer: lecturer),
        );
      },
    ),
    GoRoute(
      path: '/lecturers',
      builder: (context, state) =>
          const AuthGuard(requireAuth: true, child: LecturersScreen()),
    ),

    // Protected routes (auth required)
    GoRoute(
      path: '/home',
      builder: (context, state) =>
          const AuthGuard(requireAuth: true, child: MainNavigation()),
    ),

    // Catch-all route for unknown paths
    GoRoute(path: '/:pathMatch(.*)*', redirect: (context, state) => '/'),
  ],

  // Global error handling
  errorBuilder: (context, state) =>
      _ErrorScreen(error: state.error?.toString() ?? 'Unknown error occurred'),

  // Redirect logic for authentication
  redirect: (context, state) {
    // This will be handled by AuthGuard widgets
    return null;
  },
);

/// Global error screen for routing errors
class _ErrorScreen extends StatelessWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Error'),
        backgroundColor: AppTheme.errorColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.largePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: AppTheme.errorColor),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We encountered an unexpected error while navigating.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius,
                  ),
                  border: Border.all(color: AppTheme.textTertiary),
                ),
                child: Column(
                  children: [
                    Text(
                      'Error Details:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  context.go('/');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
