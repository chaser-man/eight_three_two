# Fix: Multiple commands produce Info.plist Error

## The Problem
Xcode is trying to generate an Info.plist automatically (`GENERATE_INFOPLIST_FILE = YES`) AND you also have a manual Info.plist file. This causes a conflict.

## Solution: Use Build Settings Instead

Since your project uses auto-generated Info.plist, we need to move all the keys from Info.plist to the build settings.

### Step 1: Remove Info.plist from Target (Don't Delete the File)

1. **In Xcode**, find `Info.plist` in the Project Navigator (left sidebar)
2. **Click on it** to select it
3. **In the right sidebar** (File Inspector), look for "Target Membership"
4. **Uncheck "eight_three"** to remove it from the target
5. **Keep the file** (we'll reference it for the values)

### Step 2: Add Keys to Build Settings

1. **Click on your project** (blue icon at top)
2. **Select the "eight_three" target**
3. **Click the "Build Settings" tab**
4. **Make sure "All" is selected** (not "Basic")
5. **In the search bar**, type "infoplist" to filter

6. **Add these keys one by one**:

   **For Camera Permission:**
   - Find or add: `INFOPLIST_KEY_NSCameraUsageDescription`
   - Set value: `Eight needs access to your camera to record videos.`

   **For Microphone Permission:**
   - Find or add: `INFOPLIST_KEY_NSMicrophoneUsageDescription`
   - Set value: `Eight needs access to your microphone to record videos with audio.`

   **For Photo Library Permission:**
   - Find or add: `INFOPLIST_KEY_NSPhotoLibraryUsageDescription`
   - Set value: `Eight needs access to your photo library to select profile pictures.`

   **For Photo Library Add Permission:**
   - Find or add: `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription`
   - Set value: `Eight needs access to save videos to your photo library.`

### Step 3: Add URL Scheme via Build Settings

This is trickier. We need to add the URL scheme. Here's how:

1. **Still in Build Settings**, search for "infoplist"
2. **Look for "Info.plist Values"** section or add a custom key
3. **Click the "+" button** to add a new key
4. **Add**: `INFOPLIST_KEY_CFBundleURLTypes`
5. **Set the type** to "Array" (you may need to edit the project.pbxproj directly for this)

**OR** use the easier method below:

### Alternative: Add URL Scheme via Info Tab

1. **Click on your project** (blue icon)
2. **Select the "eight_three" target**
3. **Click the "Info" tab** (not Build Settings)
4. **Expand "URL Types"** section
5. **Click the "+" button** to add a new URL Type
6. **Set**:
   - **Identifier**: `GoogleSignIn`
   - **URL Schemes**: `com.googleusercontent.apps.439821612620-1ft80dgrlnogkp6hihro9n5lpufuaof5`
   - **Role**: `Editor`

### Step 4: Clean and Build

1. **Product → Clean Build Folder** (Shift+Cmd+K)
2. **Product → Build** (Cmd+B)

The error should be gone!

---

## Alternative Solution: Use Manual Info.plist

If the above is too complicated, we can switch to using a manual Info.plist:

1. **In Build Settings**, find `GENERATE_INFOPLIST_FILE`
2. **Set it to `NO`** (uncheck it)
3. **Add**: `INFOPLIST_FILE` = `eight_three/Info.plist`
4. **Make sure Info.plist is in the target** (check Target Membership)

But the first solution (using build settings) is the modern approach and recommended.
