# Setup Guide for CUT Projector Tracker

This guide will help you set up the CUT Projector Tracker app with proper authentication and initial data.

## Prerequisites

- Firebase project configured (see `FIREBASE_SETUP.md`)
- Flutter development environment set up
- Android device or emulator ready

## Authentication Setup

### 1. Enable Email/Password Authentication in Firebase

1. Go to your Firebase Console
2. Navigate to Authentication > Sign-in method
3. Enable Email/Password authentication
4. Optionally, disable email verification for development (you can enable it later for production)

### 2. Configure Firestore Security Rules

Update your Firestore security rules to allow authenticated users to read/write:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow authenticated users to read/write projectors
    match /projectors/{projectorId} {
      allow read, write: if request.auth != null;
    }
    
    // Allow authenticated users to read/write lecturers
    match /lecturers/{lecturerId} {
      allow read, write: if request.auth != null;
    }
    
    // Allow authenticated users to read/write transactions
    match /transactions/{transactionId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Initial Data Setup

### 1. Create Sample Projectors

1. Go to Firestore Database in Firebase Console
2. Create a collection called `projectors`
3. Add sample documents:

#### Projector 1
```json
{
  "serialNumber": "PROJ001",
  "status": "Available",
  "lastIssuedTo": null,
  "lastIssuedDate": null,
  "lastReturnDate": null,
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-01-15T10:00:00Z"
}
```

#### Projector 2
```json
{
  "serialNumber": "PROJ002",
  "status": "Available",
  "lastIssuedTo": null,
  "lastIssuedDate": null,
  "lastReturnDate": null,
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-01-15T10:00:00Z"
}
```

### 2. Create Sample Lecturers

1. Create a collection called `lecturers`
2. Add sample documents:

#### Lecturer 1
```json
{
  "name": "Dr. John Smith",
  "department": "Computer Science",
  "email": "john.smith@cut.ac.za",
  "employeeId": "EMP001",
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-01-15T10:00:00Z"
}
```

#### Lecturer 2
```json
{
  "name": "Prof. Sarah Johnson",
  "department": "Engineering",
  "email": "sarah.johnson@cut.ac.za",
  "employeeId": "EMP002",
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-01-15T10:00Z"
}
```

## Testing the App

### 1. Build and Install

```bash
flutter build apk --debug
flutter install
```

### 2. Test Authentication Flow

1. **Splash Screen**: App should show loading animation and check auth state
2. **Sign In Screen**: 
   - Enter valid credentials
   - Test validation with invalid inputs
   - Navigate to sign up screen
3. **Sign Up Screen**: 
   - Create a new account
   - Test form validation
   - Test password strength requirements
4. **Main App**: Should navigate to home screen after successful authentication

### 3. Test Navigation

1. **Bottom Navigation**: Switch between different tabs
2. **User Profile**: Tap the user avatar in the app bar
3. **Logout**: Test logout confirmation dialog

### 4. Test Features

1. **Scan Screen**: Should show camera permission request
2. **Issue Screen**: Should show placeholder content
3. **Return Screen**: Should show placeholder content
4. **Assets Screen**: Should show placeholder content
5. **History Screen**: Should show placeholder content

## User Registration Process

### 1. New User Sign Up

1. User navigates to Sign Up screen
2. Fills in required information:
   - Full Name (first and last name required)
   - Department
   - Employee ID
   - Email Address
   - Password (minimum 8 characters, must contain uppercase, lowercase, and number)
   - Confirm Password
3. Form validation ensures data quality
4. Account is created in Firebase Authentication
5. User is redirected to Sign In screen

### 2. User Sign In

1. User enters email and password
2. Firebase Authentication validates credentials
3. On success, user is redirected to main app
4. On failure, appropriate error message is displayed

## Security Features

### 1. Route Protection

- All main app routes require authentication
- Unauthenticated users are automatically redirected to sign in
- Authenticated users cannot access sign in/sign up screens

### 2. Form Validation

- Email format validation
- Password strength requirements
- Required field validation
- Password confirmation matching

### 3. Error Handling

- User-friendly error messages
- Firebase authentication error mapping
- Network error handling
- Form validation feedback

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Check if Firebase Authentication is enabled
   - Verify email/password are correct
   - Check Firebase console for any auth errors

2. **Firestore Permission Denied**
   - Ensure Firestore security rules allow read/write
   - Check if collections exist with correct names
   - Verify user is properly authenticated

3. **App Crashes on Startup**
   - Verify Firebase configuration is correct
   - Check if all required dependencies are installed
   - Review Flutter debug console output

### Debug Mode

Run the app in debug mode to see detailed logs:

```bash
flutter run --debug
```

## Next Steps

After setting up the authentication system:

1. **Implement User Profile Management**: Save additional user data to Firestore
2. **Add Role-Based Access Control**: Different permissions for different user types
3. **Implement Password Reset**: Forgot password functionality
4. **Add Email Verification**: Require email verification for new accounts
5. **Complete Core Features**: Implement scanning, issuance, returns, assets, and history
6. **Add Offline Support**: Cache data for offline usage
7. **Implement Push Notifications**: Notify users of important events

## Support

If you encounter issues:

1. Check the Firebase console for errors
2. Review Flutter debug console output
3. Verify all setup steps were completed
4. Check the `README.md` for additional information
5. Review Firebase documentation for authentication setup
