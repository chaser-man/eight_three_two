# Quick Fix for Info.plist Error

## The Problem
Xcode is auto-generating Info.plist (`GENERATE_INFOPLIST_FILE = YES`) but you also have a manual Info.plist file, causing a conflict.

## ✅ Solution: Remove Info.plist from Target

I've already added all the permission keys to your build settings. Now you just need to:

### Step 1: Remove Info.plist from Target

1. **In Xcode**, find `Info.plist` in the Project Navigator (left sidebar)
2. **Click on it** to select it
3. **Look at the right sidebar** (File Inspector - the icon that looks like a document)
4. **Find "Target Membership"** section
5. **Uncheck "eight_three"** ✅
   - This removes it from the build but keeps the file
6. **The file will still be visible** but won't be included in the build

### Step 2: Add URL Scheme (Required for Google Sign-In)

1. **Click on your project** (blue icon at top of Project Navigator)
2. **Select the "eight_three" target** (under TARGETS)
3. **Click the "Info" tab** (at the top)
4. **Scroll down** to find "URL Types" section
5. **Click the "+" button** to add a new URL Type
6. **Fill in**:
   - **Identifier**: `GoogleSignIn`
   - **URL Schemes**: `com.googleusercontent.apps.439821612620-1ft80dgrlnogkp6hihro9n5lpufuaof5`
   - **Role**: `Editor` (default is fine)
7. **Press Enter** or click elsewhere to save

### Step 3: Clean and Build

1. **Product → Clean Build Folder** (Shift+Cmd+K)
2. **Product → Build** (Cmd+B)

The error should be gone! ✅

---

## What I Already Fixed

✅ Added all permission keys to build settings:
- Camera permission
- Microphone permission  
- Photo library permissions

These are now in the build settings, so you don't need the Info.plist file in the target anymore.

---

## If You Still Get Errors

1. **Close Xcode completely**
2. **Delete DerivedData**:
   - In Finder, press Cmd+Shift+G
   - Go to: `~/Library/Developer/Xcode/DerivedData`
   - Delete the `eight_three-*` folder
3. **Reopen Xcode**
4. **Clean and Build again**

That should fix it!
