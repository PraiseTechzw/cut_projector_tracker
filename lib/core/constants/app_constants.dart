/// App-wide constants for the CUT Projector Tracker
class AppConstants {
  // App Information
  static const String appName = 'CUT Projector Tracker';
  static const String appVersion = '1.0.0';
  
  // Firebase Collections
  static const String projectorsCollection = 'projectors';
  static const String lecturersCollection = 'lecturers';
  static const String transactionsCollection = 'transactions';
  
  // Projector Status
  static const String statusAvailable = 'Available';
  static const String statusIssued = 'Issued';
  static const String statusMaintenance = 'Maintenance';
  
  // Transaction Status
  static const String transactionActive = 'Active';
  static const String transactionReturned = 'Returned';
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double buttonHeight = 56.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Error Messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Network error. Please check your connection.';
  static const String authError = 'Authentication failed. Please login again.';
  
  // Success Messages
  static const String projectorIssued = 'Projector issued successfully!';
  static const String projectorReturned = 'Projector returned successfully!';
  static const String recordSaved = 'Record saved successfully!';
}
