# Frinder

An iPhone app that shows where your friends are as moving dots when you point your phone around.

## Features

- **User Authentication**: Create an account and log in with email/password
- **Friend Management**: Add friends by email, accept/decline friend requests
- **Location Sharing**: Share your approximate location while the app is open
- **Radar View**: See friends as dots on a blank screen that move as you rotate your phone
- **Direction Detection**: Uses compass and motion sensors to show friends in their real-world direction
- **Distance Display**: Shows how far away each friend is (km or miles)

## Requirements

- iOS 17.0+
- iPhone with compass and motion sensors
- Xcode 15.0+

## Setup

### 1. Firebase Configuration

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use an existing one
3. Add an iOS app with bundle ID `com.frinder.app`
4. Download the `GoogleService-Info.plist` file
5. Replace the placeholder file in `Frinder/Frinder/GoogleService-Info.plist`

### 2. Enable Firebase Services

In the Firebase Console, enable:

1. **Authentication**
   - Go to Authentication > Sign-in method
   - Enable "Email/Password"

2. **Cloud Firestore**
   - Go to Firestore Database
   - Create a database (start in test mode for development)
   - Set up security rules (see below)

### 3. Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      // Users can read their own data
      allow read: if request.auth != null && request.auth.uid == userId;

      // Users can write their own data
      allow write: if request.auth != null && request.auth.uid == userId;

      // Allow searching for users by email (for friend requests)
      allow read: if request.auth != null;
    }
  }
}
```

### 4. Build and Run

1. Open `Frinder/Frinder.xcodeproj` in Xcode
2. Wait for Swift Package Manager to fetch Firebase dependencies
3. Select your development team in Signing & Capabilities
4. Build and run on a physical device (simulator lacks compass/motion sensors)

## Architecture

```
Frinder/
├── FrinderApp.swift          # App entry point
├── ContentView.swift         # Root view with auth routing
├── Models/
│   ├── User.swift           # User data model
│   ├── Friend.swift         # Friend model with bearing/distance calculations
│   └── Settings.swift       # App settings (distance units)
├── Views/
│   ├── AuthView.swift       # Login/signup screen
│   ├── MainTabView.swift    # Tab container
│   ├── RadarView.swift      # Main radar display
│   ├── FriendsView.swift    # Friend management
│   └── SettingsView.swift   # App settings
├── ViewModels/
│   ├── AuthViewModel.swift  # Authentication logic
│   ├── RadarViewModel.swift # Radar state & calculations
│   └── FriendsViewModel.swift # Friend management logic
└── Services/
    ├── AuthService.swift    # Firebase Auth wrapper
    ├── LocationService.swift # CoreLocation manager
    ├── MotionService.swift  # CoreMotion manager
    └── FriendService.swift  # Firestore friend operations
```

## How It Works

1. **Location**: Uses CoreLocation with approximate accuracy (100m) to get user position
2. **Heading**: Uses compass (magnetometer) to detect which direction the phone is pointing
3. **Bearing Calculation**: Calculates the bearing from user to each friend using haversine formula
4. **Position Mapping**: Maps friend positions to screen coordinates based on relative angle to device heading

## Privacy

- Location is only shared while the app is open (no background tracking)
- Approximate location accuracy (100m) is used intentionally
- Users must explicitly add friends to share locations

## Limitations (MVP)

- No offline support
- No avatar upload (placeholder only)
- No push notifications
- Requires both users to have the app open to see each other
- Portrait orientation only
