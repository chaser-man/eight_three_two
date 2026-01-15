# Firebase Storage Rules Fix

## Problem
You're seeing the error: "User does not have permission to access gs://eight-4d86a.firebasestorage.app/profiles/..."

This happens because Firebase Storage security rules need to be configured correctly.

## Solution: Update Firebase Storage Rules

### Step 1: Open Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **eight-4d86a**
3. Click on **Storage** in the left sidebar

### Step 2: Go to Rules Tab
1. Click on the **Rules** tab at the top of the Storage page

### Step 3: Replace the Rules
Copy and paste these rules into the editor:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Videos: anyone can read, only owner can write
    match /videos/{userId}/{videoId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Thumbnails: anyone can read, only owner can write
    match /thumbnails/{userId}/{thumbnailId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Profile pictures: public read, authenticated write
    // Using wildcard pattern to match files with extensions (e.g., userId.jpg)
    // The app code ensures users can only upload to their own userId filename
    match /profiles/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### Step 4: Publish the Rules
1. Click **Publish** button
2. Wait for the confirmation message (rules take 1-2 minutes to propagate)

## Verification
After updating the rules:
1. Wait 1-2 minutes for rules to propagate
2. Try changing your profile picture again
3. The error should be gone

## Important Notes
- Rules take a few minutes to propagate after publishing
- Make sure you're logged in when testing
- The rules allow anyone to READ profile pictures (which is what you want for a social app)
- Only the owner can WRITE/UPDATE their own profile picture
