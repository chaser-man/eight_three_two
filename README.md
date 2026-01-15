# Eight - Social Media App

A SwiftUI-based social media app designed for high school students in Washington County, Utah. The app's core identity revolves around 8-second video content, with a primary focus on optimizing the feed experience for instant video loading and smooth playback.

## 🎯 Key Features

- **8-Second Videos**: Core feature - all videos are limited to 8 seconds
- **Optimized Feed**: Highly optimized for instant video loading and smooth playback
- **Video Responses**: Users can respond to videos with their own videos (nested responses supported)
- **School-Specific**: Designed for Washington County, Utah high schools
- **Google Sign-In**: Restricted to washk12.org email addresses

## 📱 Screens

1. **Feed**: Scrollable feed of videos from followed users
2. **Camera**: Record 8-second videos with countdown timer
3. **Profile**: View profile, stats, and posted videos

## 🏗️ Architecture

- **Framework**: SwiftUI (iOS 16+)
- **Pattern**: MVVM (Model-View-ViewModel)
- **Backend**: Firebase (Auth, Firestore, Storage)
- **Video**: AVFoundation for recording and playback

## 📚 Documentation

- **[DEVELOPMENT_PLAN.md](./DEVELOPMENT_PLAN.md)**: Complete development plan and architecture
- **[SETUP_INSTRUCTIONS.md](./SETUP_INSTRUCTIONS.md)**: Step-by-step Firebase and Xcode setup
- **[IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md)**: Implementation details and status
- **[QUICK_REFERENCE.md](./QUICK_REFERENCE.md)**: Quick checklist for development

## 🚀 Getting Started

1. **Follow Setup Instructions**: See [SETUP_INSTRUCTIONS.md](./SETUP_INSTRUCTIONS.md)
2. **Configure Firebase**: Create project, add iOS app, download `GoogleService-Info.plist`
3. **Add Dependencies**: Install Firebase SDK and Google Sign-In via Swift Package Manager
4. **Build & Run**: Open in Xcode and run on a physical device (camera requires real device)

## 📋 Requirements

- Xcode 15.0+
- iOS 16.0+
- Physical device for camera testing
- Firebase account
- Google Cloud Console account (for OAuth)

## 🎓 Schools Supported

- Crimson Cliffs
- Desert Hills
- Dixie
- Pine View
- Snow Canyon
- Hurricane
- Enterprise
- Water Canyon
- Career Tech
- Other

## 🔒 Security

- Email domain validation (washk12.org only)
- Firebase Security Rules
- Storage Security Rules
- User authentication required for all actions

## 📝 License

This project is private and proprietary.

## 👥 Target Audience

High school students in Washington County, Utah school district.

---

**Status**: ✅ Implementation Complete - Ready for Firebase Configuration and Testing
