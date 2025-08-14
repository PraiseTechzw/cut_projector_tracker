# CUT Projector Tracker

A Flutter mobile application for tracking projector issuance and returns using barcode/QR code scanning. Built with Clean Architecture principles and modern Flutter best practices.

## Features

- **Authentication**: Secure login using Firebase Authentication
- **Barcode/QR Scanning**: Scan projector barcodes using device camera
- **Projector Management**: Issue and return projectors to/from lecturers
- **Asset Register**: Live view of all projectors and their status
- **Transaction History**: Complete audit trail of all projector movements
- **Lecturer Management**: Search and select from predefined lecturer database
- **Real-time Updates**: Live synchronization with Firebase Firestore

## Architecture

The app follows **Clean Architecture** principles with a **Feature-First** folder structure:

```
lib/
├── core/                    # Core application layer
│   ├── constants/          # App-wide constants
│   ├── theme/             # App theme and styling
│   ├── services/          # Core services (Firebase, etc.)
│   └── utils/             # Utility functions
├── features/               # Feature modules
│   ├── auth/              # Authentication feature
│   ├── scanning/          # Barcode scanning feature
│   ├── issuance/          # Projector issuance feature
│   ├── returns/           # Projector returns feature
│   ├── assets/            # Asset management feature
│   └── history/           # Transaction history feature
└── shared/                 # Shared components
    ├── models/            # Data models
    └── widgets/           # Reusable UI components
```

## Tech Stack

- **Flutter**: 3.8.1+
- **State Management**: Riverpod with code generation
- **Backend**: Firebase (Authentication + Firestore)
- **Navigation**: GoRouter
- **Barcode Scanning**: mobile_scanner
- **UI**: Material 3 with custom theme
- **Architecture**: MVVM with Clean Architecture

## Prerequisites

- Flutter SDK 3.8.1 or higher
- Dart SDK 3.0.0 or higher
- Android Studio / VS Code
- Android device/emulator (API level 21+)
- iOS device/simulator (iOS 12.0+)

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd cut_projector_tracker
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

#### Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing one
3. Enable Authentication and Firestore Database

#### Configure Authentication

1. In Firebase Console, go to Authentication > Sign-in method
2. Enable Email/Password authentication
3. Add test users (e.g., admin@cut.ac.za / password123)

#### Configure Firestore

1. Go to Firestore Database > Create database
2. Start in test mode (for development)
3. Create the following collections:
   - `projectors`
   - `lecturers`
   - `transactions`

#### Update Firebase Configuration

1. Download your Firebase configuration files:
   - `google-services.json` for Android
   - `GoogleService-Info.plist` for iOS
2. Place them in the appropriate directories:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
3. Update `lib/firebase_options.dart` with your actual Firebase configuration

### 4. Android Configuration

The app is configured for Android API level 21+ and NDK version 27.0.12077973.

### 5. Run the App

```bash
# For Android
flutter run

# For iOS
flutter run -d ios
```

## Database Schema

### Collections

#### `projectors`
```json
{
  "id": "auto-generated",
  "serialNumber": "PROJ001",
  "status": "Available|Issued|Maintenance",
  "lastIssuedTo": "Dr. John Doe",
  "lastIssuedDate": "timestamp",
  "lastReturnDate": "timestamp",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### `lecturers`
```json
{
  "id": "auto-generated",
  "name": "Dr. John Doe",
  "department": "Computer Science",
  "email": "john.doe@cut.ac.za",
  "employeeId": "EMP001",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### `transactions`
```json
{
  "id": "auto-generated",
  "projectorId": "projector-id",
  "lecturerId": "lecturer-id",
  "projectorSerialNumber": "PROJ001",
  "lecturerName": "Dr. John Doe",
  "status": "Active|Returned",
  "dateIssued": "timestamp",
  "dateReturned": "timestamp",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Usage

### Authentication
- Use the provided demo credentials or create your own Firebase users
- Only authenticated staff can access the system

### Scanning Projectors
1. Navigate to the Scan tab
2. Point camera at projector barcode/QR code
3. View projector information and status

### Issuing Projectors
1. Scan projector barcode
2. Select lecturer from the list
3. Confirm issuance
4. Projector status updates to "Issued"

### Returning Projectors
1. Scan projector barcode
2. Confirm return
3. Projector status updates to "Available"

### Asset Management
- View all projectors in real-time
- Sort by status, date, or lecturer
- Search by serial number

### History & Reporting
- View complete transaction history
- Filter by date range, lecturer, or projector
- Export data to CSV (coming soon)

## Development

### Code Generation

The app uses Riverpod code generation. After making changes to providers, run:

```bash
flutter packages pub run build_runner build
```

### Adding New Features

1. Create feature directory under `lib/features/`
2. Follow the existing structure: `presentation/screens/`
3. Add navigation routes in `lib/main.dart`
4. Update the main navigation widget

### Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/
```

## Building for Production

### Android APK

```bash
flutter build apk --release
```

### Android App Bundle

```bash
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Troubleshooting

### Common Issues

1. **Firebase Configuration**: Ensure all Firebase configuration files are properly placed
2. **Camera Permissions**: Grant camera permissions when prompted
3. **Network Issues**: Check internet connection for Firestore operations
4. **Build Errors**: Ensure Flutter and Dart versions are compatible

### Debug Mode

For development, use debug mode to see detailed error messages:

```bash
flutter run --debug
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation

## Roadmap

- [ ] Dark theme support
- [ ] Offline mode with local storage
- [ ] Push notifications for overdue returns
- [ ] Advanced reporting and analytics
- [ ] Multi-language support
- [ ] Admin panel for user management
- [ ] Integration with existing CUT systems
