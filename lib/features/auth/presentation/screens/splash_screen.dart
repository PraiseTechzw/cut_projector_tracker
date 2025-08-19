import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/permission_service.dart';

/// Splash screen shown when the app starts
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late AnimationController _textAnimationController;
  late AnimationController _loadingAnimationController;
  
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _loadingRotationAnimation;
  
  bool _isInitialized = false;
  bool _permissionsChecked = false;
  CameraPermissionResult? _cameraPermissionResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    // Logo animations
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _logoScaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    // Text animations
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
    ));

    _textSlideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    // Loading animation
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _loadingRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingAnimationController,
      curve: Curves.linear,
    ));
  }

  void _startAnimations() async {
    // Start logo animation
    await _logoAnimationController.forward();
    
    // Start text animation
    await _textAnimationController.forward();
    
    // Start loading animation
    _loadingAnimationController.repeat();
    
    // Wait a bit then check auth
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _checkAuthAndNavigate();
    }
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _textAnimationController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  /// Check authentication state and navigate accordingly
  Future<void> _checkAuthAndNavigate() async {
    try {
      setState(() {
        _isInitialized = true;
      });

      // First, check camera permissions (professional apps do this early)
      await _checkCameraPermissions();

      // Wait a bit for Firebase to initialize
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        final user = ref.read(currentUserProvider);
        if (user != null) {
          _navigateToHome();
        } else {
          _navigateToLogin();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize app: ${e.toString()}';
        });
        
        // Show error and retry option
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _navigateToLogin();
        }
      }
    }
  }

  /// Check camera permissions early in app lifecycle
  Future<void> _checkCameraPermissions() async {
    try {
      final permissionService = ref.read(permissionServiceProvider);
      final result = await permissionService.initializeCameraPermission();
      
      if (mounted) {
        setState(() {
          _cameraPermissionResult = result;
          _permissionsChecked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraPermissionResult = CameraPermissionResult.error;
          _permissionsChecked = true;
        });
      }
    }
  }

  void _navigateToHome() {
    context.go('/home');
  }

  void _navigateToLogin() {
    context.go('/signin');
  }

  String _getLoadingText() {
    if (!_permissionsChecked) {
      return 'Checking permissions...';
    }
    return 'Initializing...';
  }

  IconData _getPermissionIcon() {
    switch (_cameraPermissionResult) {
      case CameraPermissionResult.granted:
        return Icons.check_circle;
      case CameraPermissionResult.denied:
      case CameraPermissionResult.permanentlyDenied:
      case CameraPermissionResult.restricted:
        return Icons.warning;
      case CameraPermissionResult.error:
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Color _getPermissionColor() {
    switch (_cameraPermissionResult) {
      case CameraPermissionResult.granted:
        return Colors.green;
      case CameraPermissionResult.denied:
      case CameraPermissionResult.permanentlyDenied:
      case CameraPermissionResult.restricted:
        return Colors.orange;
      case CameraPermissionResult.error:
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getPermissionStatusText() {
    switch (_cameraPermissionResult) {
      case CameraPermissionResult.granted:
        return 'Camera access granted';
      case CameraPermissionResult.denied:
        return 'Camera access denied';
      case CameraPermissionResult.permanentlyDenied:
        return 'Camera permanently denied';
      case CameraPermissionResult.restricted:
        return 'Camera access restricted';
      case CameraPermissionResult.error:
        return 'Camera permission error';
      default:
        return 'Checking camera access...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Section
              AnimatedBuilder(
                animation: _logoAnimationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _logoFadeAnimation,
                    child: ScaleTransition(
                      scale: _logoScaleAnimation,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(35),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.4),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.video_camera_front,
                          size: 70,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // App Name
              AnimatedBuilder(
                animation: _textAnimationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _textFadeAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_textSlideAnimation),
                      child: Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // App Description
              AnimatedBuilder(
                animation: _textAnimationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _textFadeAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_textSlideAnimation),
                      child: Text(
                        'Track projector issuance and returns',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 60),

              // Loading Section
              if (_isInitialized) ...[
                AnimatedBuilder(
                  animation: _loadingAnimationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _loadingRotationAnimation.value * 2 * 3.14159,
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                        strokeWidth: 3,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  _getLoadingText(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Permission status indicator
                if (_permissionsChecked && _cameraPermissionResult != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getPermissionIcon(),
                        size: 16,
                        color: _getPermissionColor(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getPermissionStatusText(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getPermissionColor(),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                const SizedBox(height: 20),
                Text(
                  'Loading...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],

              // Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    border: Border.all(color: AppTheme.errorColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Version Info
              const SizedBox(height: 60),
              Text(
                'Version 1.0.0',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
