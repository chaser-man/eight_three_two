# Fix Provisioning Profile Error for Personal Development Account

## The Problem

Personal (free) Apple Developer accounts don't support the **Associated Domains** capability, which was in your entitlements file. This prevents creating provisioning profiles.

## ✅ What I Fixed

I **removed the Associated Domains** from your `eight_three.entitlements` file. This capability is only needed for:
- Universal Links (deep linking from web to app)
- App Clips
- Other advanced features

**Your app will work fine without it!** Firebase and Google Sign-In don't require Associated Domains.

## Next Steps

### Step 1: Clean Build Folder

1. **Product → Clean Build Folder** (Shift+Cmd+K)

### Step 2: Select Your iPhone

1. **Connect your iPhone** via USB
2. **Unlock your iPhone** and trust the computer if prompted
3. **In Xcode**, select your iPhone from the device dropdown (top toolbar)

### Step 3: Trust Your Development Certificate (First Time Only)

1. **On your iPhone**, go to: **Settings → General → VPN & Device Management**
2. **Tap on your developer certificate** (your name/email)
3. **Tap "Trust [Your Name]"**
4. **Confirm** by tapping "Trust"

### Step 4: Build and Run

1. **Product → Build** (Cmd+B) - should succeed now
2. **Product → Run** (Cmd+R) - should install on your iPhone

## If You Still Get Errors

### Error: "No profiles found"

1. **In Xcode**, click on your **project** (blue icon)
2. **Select the "eight_three" target**
3. **Go to "Signing & Capabilities" tab**
4. **Check "Automatically manage signing"**
5. **Select your Team** (should show "Chase Nielsen (Personal Team)")
6. **Xcode will automatically create a provisioning profile**

### Error: "Signing certificate not found"

1. **Xcode → Preferences → Accounts**
2. **Add your Apple ID** if not already added
3. **Select your account** and click **"Download Manual Profiles"**
4. **Go back to Signing & Capabilities** and try again

### Error: "Device not registered"

1. **Window → Devices and Simulators** (Shift+Cmd+2)
2. **Select your iPhone** in the left sidebar
3. **Click "Use for Development"** if prompted
4. **You may need to enter your Mac password**

## What Was Removed

The Associated Domains capability was removed. This means:
- ❌ No universal links (web links won't automatically open the app)
- ✅ Everything else works: Firebase, Google Sign-In, camera, videos, etc.

**Note**: If you later get a paid Apple Developer account ($99/year), you can add Associated Domains back if needed.

## Summary

✅ Removed Associated Domains from entitlements  
✅ App should now build to your iPhone  
✅ All core features will work  

Try building again - it should work now! 🎉
