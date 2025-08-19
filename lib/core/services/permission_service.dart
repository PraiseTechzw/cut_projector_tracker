import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for managing app permissions
class PermissionService {
  /// Check camera permission status
  Future<PermissionStatus> getCameraPermissionStatus() async {
    return await Permission.camera.status;
  }

  /// Request camera permission
  Future<PermissionStatus> requestCameraPermission() async {
    return await Permission.camera.request();
  }

  /// Check if camera permission is granted
  Future<bool> isCameraPermissionGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Check if camera permission is permanently denied
  Future<bool> isCameraPermissionPermanentlyDenied() async {
    final status = await Permission.camera.status;
    return status.isPermanentlyDenied;
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  /// Initialize and check camera permission
  /// This should be called early in the app lifecycle
  Future<CameraPermissionResult> initializeCameraPermission() async {
    try {
      // First check current status
      final currentStatus = await Permission.camera.status;

      if (currentStatus.isGranted) {
        return CameraPermissionResult.granted;
      }

      if (currentStatus.isPermanentlyDenied) {
        return CameraPermissionResult.permanentlyDenied;
      }

      if (currentStatus.isRestricted) {
        return CameraPermissionResult.restricted;
      }

      // If not granted and not permanently denied, request permission
      final requestResult = await Permission.camera.request();

      switch (requestResult) {
        case PermissionStatus.granted:
          return CameraPermissionResult.granted;
        case PermissionStatus.denied:
          return CameraPermissionResult.denied;
        case PermissionStatus.permanentlyDenied:
          return CameraPermissionResult.permanentlyDenied;
        case PermissionStatus.restricted:
          return CameraPermissionResult.restricted;
        default:
          return CameraPermissionResult.denied;
      }
    } catch (e) {
      return CameraPermissionResult.error;
    }
  }
}

/// Camera permission result enum
enum CameraPermissionResult {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  error,
}

/// Extension for CameraPermissionResult
extension CameraPermissionResultExtension on CameraPermissionResult {
  bool get isGranted => this == CameraPermissionResult.granted;
  bool get isDenied => this == CameraPermissionResult.denied;
  bool get isPermanentlyDenied =>
      this == CameraPermissionResult.permanentlyDenied;
  bool get isRestricted => this == CameraPermissionResult.restricted;
  bool get hasError => this == CameraPermissionResult.error;

  String get description {
    switch (this) {
      case CameraPermissionResult.granted:
        return 'Camera permission granted';
      case CameraPermissionResult.denied:
        return 'Camera permission denied';
      case CameraPermissionResult.permanentlyDenied:
        return 'Camera permission permanently denied';
      case CameraPermissionResult.restricted:
        return 'Camera access restricted';
      case CameraPermissionResult.error:
        return 'Error checking camera permission';
    }
  }
}

/// Riverpod provider for PermissionService
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

/// Provider for camera permission status
final cameraPermissionProvider = FutureProvider<CameraPermissionResult>((
  ref,
) async {
  final permissionService = ref.read(permissionServiceProvider);
  return await permissionService.initializeCameraPermission();
});
