# Firebase Setup Guide for CUT Projector Tracker

This guide will help you set up Firebase for the CUT Projector Tracker app.

## Prerequisites

- Google account
- Flutter project set up and running

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter project name: `cut-projector-tracker` (or your preferred name)
4. Choose whether to enable Google Analytics (recommended)
5. Click "Create project"

## Step 2: Add Android App

1. In your Firebase project, click the Android icon (</>) to add an Android app
2. Enter Android package name: `com.example.cut_projector_tracker`
3. Enter app nickname: `CUT Projector Tracker`
4. Click "Register app"
5. Download the `google-services.json` file
6. Place it in `android/app/google-services.json`

## Step 3: Add iOS App (Optional)

1. Click the iOS icon (</>) to add an iOS app
2. Enter iOS bundle ID: `com.example.cutProjectorTracker`
3. Enter app nickname: `CUT Projector Tracker`
4. Click "Register app"
5. Download the `GoogleService-Info.plist` file
6. Place it in `ios/Runner/GoogleService-Info.plist`

## Step 4: Enable Authentication

1. In Firebase Console, go to "Authentication" > "Sign-in method"
2. Click "Email/Password"
3. Enable it and click "Save"
4. Go to "Users" tab and click "Add user"
5. Add a test user:
   - Email: `admin@cut.ac.za`
   - Password: `password123`

## Step 5: Enable Firestore Database

1. Go to "Firestore Database" in the left sidebar
2. Click "Create database"
3. Choose "Start in test mode" (for development)
4. Select a location close to your users
5. Click "Enable"

## Step 6: Create Firestore Collections

Create the following collections in your Firestore database:

### `projectors` Collection
```json
{
  "serialNumber": "PROJ001",
  "status": "Available",
  "lastIssuedTo": null,
  "lastIssuedDate": null,
  "lastReturnDate": null,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

### `lecturers` Collection
```json
{
  "name": "Dr. John Doe",
  "department": "Computer Science",
  "email": "john.doe@cut.ac.za",
  "employeeId": "EMP001",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

### `transactions` Collection
```json
{
  "projectorId": "projector-id",
  "lecturerId": "lecturer-id",
  "projectorSerialNumber": "PROJ001",
  "lecturerName": "Dr. John Doe",
  "status": "Active",
  "dateIssued": "2024-01-01T00:00:00Z",
  "dateReturned": null,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

## Step 7: Update Firebase Configuration

1. Update `lib/firebase_options.dart` with your actual Firebase configuration
2. Replace the placeholder values with your actual Firebase project settings

## Step 8: Test the App

1. Run `flutter pub get` to install dependencies
2. Run `flutter run` to test the app
3. Try logging in with the test credentials
4. Test the barcode scanning functionality

## Security Rules (Optional)

For production, you should set up proper Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **Build fails with Firebase errors**: Ensure `google-services.json` is in the correct location
2. **Authentication not working**: Check if Email/Password is enabled in Firebase Console
3. **Firestore access denied**: Ensure you're in test mode or have proper security rules
4. **App crashes on startup**: Check Firebase configuration in `firebase_options.dart`

### Getting Help

- Check Firebase documentation: [https://firebase.google.com/docs](https://firebase.google.com/docs)
- Flutter Firebase plugin: [https://firebase.flutter.dev/](https://firebase.flutter.dev/)
- Create an issue in the project repository

## Next Steps

After setting up Firebase:

1. Add more test data (projectors, lecturers)
2. Test all app features
3. Set up proper security rules for production
4. Configure Firebase Analytics and Crashlytics
5. Set up Firebase Hosting for web version (optional)


