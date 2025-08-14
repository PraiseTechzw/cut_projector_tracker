# Demo Setup Guide for CUT Projector Tracker

This guide will help you set up demo data and test the authentication system for the CUT Projector Tracker app.

## Prerequisites

- Firebase project configured (see `FIREBASE_SETUP.md`)
- Flutter development environment set up
- Android device or emulator ready

## Demo Credentials

The app comes with pre-configured demo credentials:

- **Email**: `admin@cut.ac.za`
- **Password**: `password123`

These credentials are pre-filled in the login screen for easy testing.

## Setting Up Demo Data

### 1. Create Demo User in Firebase Authentication

1. Go to your Firebase Console
2. Navigate to Authentication > Users
3. Click "Add User"
4. Enter the demo credentials:
   - Email: `admin@cut.ac.za`
   - Password: `password123`
5. Click "Add user"

### 2. Add Sample Projectors to Firestore

1. Go to Firestore Database in Firebase Console
2. Create a collection called `projectors`
3. Add the following sample documents:

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

#### Projector 3
```json
{
  "serialNumber": "PROJ003",
  "status": "Issued",
  "lastIssuedTo": "Dr. John Smith",
  "lastIssuedDate": "2024-01-20T09:00:00Z",
  "lastReturnDate": null,
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-01-20T09:00:00Z"
}
```

### 3. Add Sample Lecturers

1. Create a collection called `lecturers`
2. Add the following sample documents:

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
  "updatedAt": "2024-01-15T10:00:00Z"
}
```

#### Lecturer 3
```json
{
  "name": "Dr. Michael Brown",
  "department": "Mathematics",
  "email": "michael.brown@cut.ac.za",
  "employeeId": "EMP003",
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-01-15T10:00:00Z"
}
```

### 4. Add Sample Transactions

1. Create a collection called `transactions`
2. Add the following sample documents:

#### Active Transaction
```json
{
  "projectorId": "PROJ003",
  "lecturerId": "EMP001",
  "projectorSerialNumber": "PROJ003",
  "lecturerName": "Dr. John Smith",
  "status": "Active",
  "dateIssued": "2024-01-20T09:00:00Z",
  "dateReturned": null,
  "createdAt": "2024-01-20T09:00:00Z",
  "updatedAt": "2024-01-20T09:00:00Z"
}
```

#### Completed Transaction
```json
{
  "projectorId": "PROJ001",
  "lecturerId": "EMP002",
  "projectorSerialNumber": "PROJ001",
  "lecturerName": "Prof. Sarah Johnson",
  "status": "Completed",
  "dateIssued": "2024-01-18T14:00:00Z",
  "dateReturned": "2024-01-19T16:00:00Z",
  "createdAt": "2024-01-18T14:00:00Z",
  "updatedAt": "2024-01-19T16:00:00Z"
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
2. **Login Screen**: 
   - Demo credentials should be pre-filled
   - Try logging in with demo credentials
   - Test validation with invalid inputs
   - Use "Quick Demo Login" button for faster testing
3. **Main App**: Should navigate to home screen after successful login

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

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Check if demo user exists in Firebase Auth
   - Verify email/password are correct
   - Check Firebase console for any auth errors

2. **Firestore Permission Denied**
   - Ensure Firestore security rules allow read/write
   - Check if collections exist with correct names

3. **App Crashes on Startup**
   - Verify Firebase configuration is correct
   - Check if all required dependencies are installed

### Debug Mode

Run the app in debug mode to see detailed logs:

```bash
flutter run --debug
```

## Next Steps

After testing the authentication system:

1. Implement the scanning functionality
2. Complete the issuance and return screens
3. Build the assets register with live data
4. Implement transaction history and reporting
5. Add more sophisticated error handling
6. Implement offline capabilities

## Support

If you encounter issues:

1. Check the Firebase console for errors
2. Review Flutter debug console output
3. Verify all setup steps were completed
4. Check the `README.md` for additional information
