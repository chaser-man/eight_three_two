# Eight - Quick Reference Checklist

## Frameworks Summary
- **SwiftUI** - UI Framework
- **AVFoundation** - Camera & Video
- **AVKit** - Video Player UI
- **Combine** - Reactive Programming
- **Firebase Auth** - Authentication
- **Firebase Firestore** - Database
- **Firebase Storage** - File Storage
- **GoogleSignIn SDK** - Google Auth
- **PhotosUI** - Photo Library
- **Core Image** - Video/Image Processing

## Core Requirements Checklist

### Onboarding
- [ ] Google Sign-In with washk12.org validation
- [ ] School selection (10 options)
- [ ] Grade selection (9, 10, 11, 12, Other)
- [ ] Profile setup (picture, name, bio)

### Profile Screen
- [ ] Profile picture (editable on tap)
- [ ] User stats (friends, videos, followers)
- [ ] User's videos grid
- [ ] Settings icon → Settings screen
- [ ] Search icon → Search screen
- [ ] Edit profile functionality

### Camera Screen
- [ ] Live camera preview
- [ ] Record button
- [ ] 8-second countdown timer
- [ ] Auto-stop at 8 seconds
- [ ] Manual stop before 8 seconds
- [ ] Zoom control
- [ ] Editing screen (crop, text overlay)
- [ ] Preview screen
- [ ] Post/Cancel actions

### Feed Screen (PRIORITY #1)
- [ ] Vertical scrolling feed
- [ ] Videos from followed users
- [ ] Instant video loading (optimized)
- [ ] Like button (bottom left, semi-transparent)
- [ ] Dislike button (bottom left, semi-transparent)
- [ ] Record Response button (bottom right)
- [ ] View Responses button (bottom right)
- [ ] Auto-play current video
- [ ] Pause when scrolling away

### Video Responses
- [ ] Record response (reuse camera code)
- [ ] View responses screen
- [ ] Sort by likes (descending)
- [ ] Tiebreaker: most recent
- [ ] Nested responses support
- [ ] Like/dislike on responses
- [ ] Record response on responses
- [ ] View responses on responses

### Settings
- [ ] Account settings
- [ ] Privacy settings
- [ ] Notification preferences
- [ ] App settings
- [ ] Logout
- [ ] Delete account

### Search
- [ ] Search bar
- [ ] Filter by school
- [ ] Filter by grade
- [ ] User results list
- [ ] Follow/Unfollow button
- [ ] Tap to view profile

## Performance Optimization (Feed)
- [ ] Lazy loading (LazyVStack)
- [ ] Video preloading (next 2-3 videos)
- [ ] Thumbnail-first loading
- [ ] Video caching (local storage)
- [ ] Video compression (720p, H.264, <5MB)
- [ ] Firestore query optimization
- [ ] Pagination (20 videos per page)
- [ ] Real-time updates (Firestore listeners)
- [ ] Player instance reuse
- [ ] Background preloading (WiFi only)

## Firebase Setup
- [ ] Create Firebase project
- [ ] Add iOS app
- [ ] Download GoogleService-Info.plist
- [ ] Enable Google Sign-In
- [ ] Configure Firestore database
- [ ] Set up Storage bucket
- [ ] Create security rules
- [ ] Create indexes:
  - [ ] videos: userId, createdAt
  - [ ] videos: parentVideoId, likeCount, createdAt
  - [ ] users: school, grade
  - [ ] follows: followerId, followingId
  - [ ] interactions: userId, videoId

## Development Phases
1. [ ] Foundation & Setup (Week 1-2)
2. [ ] Onboarding (Week 2-3)
3. [ ] Camera & Recording (Week 3-4)
4. [ ] Profile Screen (Week 4-5)
5. [ ] Feed Screen (Week 5-7) - **CRITICAL**
6. [ ] Video Responses (Week 7-8)
7. [ ] Polish & Optimization (Week 8-9)
8. [ ] Testing & Deployment (Week 9-10)

## Key Architecture Decisions
- **Pattern**: MVVM (Model-View-ViewModel)
- **State Management**: Combine + @StateObject/@ObservedObject
- **Navigation**: NavigationStack (iOS 16+)
- **Video Player**: AVPlayer with reuse strategy
- **Caching**: NSCache (memory) + Disk cache
- **Database**: Firestore with real-time listeners

## Critical Constraints
- ✅ 8-second video limit (enforced everywhere)
- ✅ washk12.org email only
- ✅ Feed performance is #1 priority
- ✅ Intuitive and simple UI
- ✅ School-specific (Washington County, Utah)

## Testing Checklist
- [ ] Unit tests for ViewModels
- [ ] Unit tests for Services
- [ ] UI tests for onboarding
- [ ] UI tests for camera recording
- [ ] UI tests for feed interactions
- [ ] Performance tests
- [ ] Beta testing with target users

## App Store Preparation
- [ ] App icon
- [ ] Screenshots (all device sizes)
- [ ] App description
- [ ] Keywords
- [ ] Privacy policy URL
- [ ] Terms of service URL
- [ ] Age rating (13+ for social media)
- [ ] Content rating
