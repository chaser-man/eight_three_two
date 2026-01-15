# Eight App - Setup Instructions

## Prerequisites

1. **Xcode 15.0 or later**
2. **iOS 16.0+ deployment target**
3. **Firebase account** (free tier is sufficient)
4. **Google Sign-In credentials**

## Firebase Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Name it "Eight" (or your preferred name)
4. Follow the setup wizard

### 2. Add iOS App to Firebase

1. In Firebase Console, click "Add app" → iOS
2. Register your app:
   - **Bundle ID**: Use your app's bundle identifier (e.g., `com.yourname.eight`)
   - **App nickname**: "Eight iOS"
   - **App Store ID**: Leave blank for now
3. Download `GoogleService-Info.plist`
4. Add `GoogleService-Info.plist` to your Xcode project:
   - Drag it into the `eight_three` folder in Xcode
   - Make sure "Copy items if needed" is checked
   - Add to target: `eight_three`

### 3. Enable Firebase Services

#### Authentication
1. Go to **Authentication** → **Sign-in method**
2. Enable **Google** sign-in
3. Add your iOS app's bundle ID
4. Download the configuration file again if needed

#### Firestore Database
1. Go to **Firestore Database**
2. Click "Create database"
3. Start in **test mode** (we'll add security rules later)
4. Choose a location (closest to your users)

#### Storage
1. Go to **Storage**
2. Click "Get started"
3. Start in **test mode**
4. Choose same location as Firestore

### 4. Firestore Security Rules

Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Videos collection
    match /videos/{videoId} {
      allow read: if true;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null && 
                       (resource.data.userId == request.auth.uid || 
                        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['likeCount', 'dislikeCount', 'responseCount']));
      allow delete: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
    }
    
    // Interactions collection
    match /interactions/{interactionId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow delete: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
    }
    
    // Follows collection
    match /follows/{followId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
                       request.resource.data.followerId == request.auth.uid;
      allow delete: if request.auth != null && 
                       request.resource.data.followerId == request.auth.uid;
    }
  }
}
```

### 5. Storage Security Rules

Replace the default rules with:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /videos/{userId}/{videoId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /thumbnails/{userId}/{thumbnailId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /profiles/{userId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 6. Create Firestore Indexes

Go to **Firestore** → **Indexes** and create these composite indexes:

1. **Collection**: `videos`
   - Fields: `userId` (Ascending), `createdAt` (Descending)
   - Query scope: Collection

2. **Collection**: `videos`
   - Fields: `parentVideoId` (Ascending), `likeCount` (Descending), `createdAt` (Descending)
   - Query scope: Collection

3. **Collection**: `users`
   - Fields: `school` (Ascending), `grade` (Ascending)
   - Query scope: Collection

## Xcode Setup

### 1. Add Firebase SDK

1. In Xcode, go to **File** → **Add Packages...**
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Select these packages:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseStorage`
   - `FirebaseCore`
4. Click "Add Package"

### 2. Add Google Sign-In SDK

1. Go to **File** → **Add Packages...**
2. Enter: `https://github.com/google/GoogleSignIn-iOS`
3. Select the package
4. Click "Add Package"

### 3. Configure URL Scheme

1. In Xcode, select your project
2. Go to **Info** tab
3. Under **URL Types**, click **+**
4. Add:
   - **Identifier**: `GoogleSignIn`
   - **URL Schemes**: Get this from your `GoogleService-Info.plist` → `REVERSED_CLIENT_ID`

### 4. Update Info.plist

The `Info.plist` file has been created with required permissions. Make sure it's added to your target.

### 5. Update Deployment Target

1. Select your project in Xcode
2. Go to **General** tab
3. Set **iOS Deployment Target** to **16.0** or higher

## Google Sign-In Configuration

### 1. Get OAuth Client ID

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create one)
3. Go to **APIs & Services** → **Credentials**
4. Create **OAuth 2.0 Client ID** (iOS application)
5. Add your bundle ID
6. Copy the **Client ID**

### 2. Add to Firebase

1. In Firebase Console → **Authentication** → **Sign-in method** → **Google**
2. Add the **iOS Client ID** from Google Cloud Console
3. Save

## Testing

### 1. Test on Simulator

- Camera features require a physical device
- Use iPhone 14 Pro or later for best results

### 2. Test on Physical Device

1. Connect your iPhone
2. Select it as the run destination
3. Build and run
4. You may need to trust the developer certificate on your device

## Troubleshooting

### Common Issues

1. **"GoogleService-Info.plist not found"**
   - Make sure the file is in the project root
   - Check it's added to the target

2. **"Camera not available"**
   - Test on a physical device (simulator doesn't have camera)
   - Check Info.plist has camera permission

3. **"Firebase not configured"**
   - Make sure `FirebaseApp.configure()` is called in `eight_threeApp.swift`
   - Verify `GoogleService-Info.plist` is correct

4. **"Google Sign-In fails"**
   - Check URL scheme is configured
   - Verify OAuth Client ID is set in Firebase
   - Make sure you're using a washk12.org email

5. **"Video upload fails"**
   - Check Storage rules
   - Verify Storage is enabled in Firebase Console
   - Check network connection

## Next Steps

1. **Customize App Icon**: Replace the default icon in `Assets.xcassets`
2. **Add App Store Assets**: Screenshots, descriptions, etc.
3. **Test Thoroughly**: Test all features on physical devices
4. **Beta Testing**: Use TestFlight for beta testing
5. **App Store Submission**: Follow Apple's guidelines

## Additional Resources

- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [Google Sign-In iOS](https://developers.google.com/identity/sign-in/ios)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [AVFoundation Documentation](https://developer.apple.com/documentation/avfoundation)
