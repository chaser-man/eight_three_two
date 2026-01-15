# Add Firebase Packages - Step by Step

## The Problem
The Firebase SDK packages haven't been added to your project yet. You need to add them via Swift Package Manager.

## Required Packages

You need to add these 5 packages:
1. **FirebaseCore** (required)
2. **FirebaseAuth** (for Google Sign-In)
3. **FirebaseFirestore** (for database)
4. **FirebaseStorage** (for video/image storage)
5. **GoogleSignIn-iOS** (for Google authentication)

---

## Step-by-Step Instructions

### Step 1: Add Firebase SDK

1. **Open Xcode**
2. **Click on your project** (blue icon at top of Project Navigator)
3. **Go to File → Add Packages...** (or press Shift+Cmd+0, then type "Add Packages")
4. **In the search bar** at the top right, paste this URL:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
5. **Press Enter** or click the search button
6. **Wait for it to load** (you'll see "firebase-ios-sdk" appear)
7. **Click on "firebase-ios-sdk"** in the list
8. **On the right side**, you'll see "Add to Project" and package options
9. **Set "Dependency Rule"** to "Up to Next Major Version" (default is fine)
10. **In the "Add to Target" section**, make sure **"eight_three"** is checked ✅
11. **Click "Add Package"** button at the bottom right

### Step 2: Select Firebase Modules

After clicking "Add Package", a new window will appear asking which modules to add:

1. **Check these boxes** (you'll see a list of Firebase modules):
   - ✅ **FirebaseAuth**
   - ✅ **FirebaseFirestore**
   - ✅ **FirebaseStorage**
   - ✅ **FirebaseCore** (usually selected by default)

2. **Make sure "eight_three" target is selected** in the "Add to Target" column for each

3. **Click "Add Package"** at the bottom

4. **Wait for it to download and integrate** (this may take a minute)

### Step 3: Add Google Sign-In SDK

1. **Go to File → Add Packages...** again
2. **In the search bar**, paste this URL:
   ```
   https://github.com/google/GoogleSignIn-iOS
   ```
3. **Press Enter**
4. **Click on "GoogleSignIn-iOS"** when it appears
5. **Set "Dependency Rule"** to "Up to Next Major Version"
6. **Make sure "eight_three" target is checked** ✅
7. **Click "Add Package"**
8. **In the module selection**, make sure **"GoogleSignIn"** is checked ✅
9. **Click "Add Package"**

### Step 4: Verify Packages Are Added

1. **Click on your project** (blue icon)
2. **Select the "eight_three" target**
3. **Click "Package Dependencies" tab** (at the top, next to "Build Settings")
4. **You should see**:
   - firebase-ios-sdk
   - GoogleSignIn-iOS

### Step 5: Build the Project

1. **Product → Clean Build Folder** (Shift+Cmd+K)
2. **Product → Build** (Cmd+B)
3. **The errors should be gone!** ✅

---

## Troubleshooting

### "Package not found"
- Make sure you're connected to the internet
- Try the URL again
- Check that you're using the exact URLs above

### "Add Package button is grayed out"
- Make sure you've selected the package in the list
- Make sure a target is selected

### "Still getting module errors after adding"
1. **Clean Build Folder** (Shift+Cmd+K)
2. **Close Xcode completely**
3. **Delete DerivedData**:
   - In Finder, press Cmd+Shift+G
   - Go to: `~/Library/Developer/Xcode/DerivedData`
   - Delete the `eight_three-*` folder
4. **Reopen Xcode**
5. **Build again** (Cmd+B)

### "Packages are added but still errors"
- Make sure all 4 Firebase modules are selected (Auth, Firestore, Storage, Core)
- Make sure GoogleSignIn is selected
- Check that "eight_three" target is checked for all packages

---

## Quick Checklist

- [ ] Firebase SDK added (firebase-ios-sdk)
- [ ] FirebaseAuth module selected
- [ ] FirebaseFirestore module selected
- [ ] FirebaseStorage module selected
- [ ] FirebaseCore module selected
- [ ] GoogleSignIn-iOS package added
- [ ] All packages added to "eight_three" target
- [ ] Cleaned build folder
- [ ] Built successfully (Cmd+B)

Once all packages are added, your project should build without errors! 🎉
