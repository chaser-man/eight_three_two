# Eight - Development Plan

## Overview
"Eight" is a social media app built with Swift and SwiftUI, designed specifically for high school students in Washington County, Utah. The app's core identity revolves around 8-second video content, with a primary focus on optimizing the feed experience for instant video loading and smooth playback.

---

## Frameworks & Technologies

### Core Frameworks
1. **SwiftUI** - Primary UI framework (prioritized over UIKit)
2. **AVFoundation** - Camera access, video recording, playback, and editing
3. **AVKit** - Video player UI components
4. **Combine** - Reactive programming for state management and data flow
5. **Foundation** - Core Swift functionality

### Firebase Services
6. **Firebase Auth** - User authentication (Google Sign-In integration)
7. **Firebase Firestore** - Real-time database for user data, videos, likes, responses
8. **Firebase Storage** - Video and image file storage
9. **Firebase Analytics** - User behavior tracking (optional)

### Third-Party SDKs
10. **GoogleSignIn SDK** - Google authentication integration
11. **SDWebImageSwiftUI** (or similar) - Efficient image loading and caching

### Additional Frameworks
12. **PhotosUI** - Photo library access (for profile picture selection)
13. **Core Image** - Video/image processing (cropping, filters, text overlay)
14. **Core Data** (optional) - Local caching for offline support

---

## Architecture Overview

### Design Pattern: MVVM (Model-View-ViewModel)
- **Models**: Data structures (User, Video, Response, etc.)
- **Views**: SwiftUI views for each screen
- **ViewModels**: Business logic and state management
- **Services**: Repository pattern for Firebase operations
- **Managers**: Camera, Video, Auth managers

### Key Architectural Principles
1. **Feed-First Optimization**: All architecture decisions prioritize feed performance
2. **Lazy Loading**: Videos load only when needed
3. **Preloading Strategy**: Preload next 2-3 videos in feed
4. **Caching Layer**: Local cache for videos, thumbnails, and user data
5. **Reactive Data Flow**: Combine publishers for real-time updates

---

## Data Models

### User Model
```swift
struct User: Codable, Identifiable {
    let id: String
    let email: String // washk12.org email
    let displayName: String
    let profilePictureURL: String?
    let school: School
    let grade: Grade
    let bio: String?
    let createdAt: Timestamp
    let followerCount: Int
    let followingCount: Int
    let videoCount: Int
}
```

### Video Model
```swift
struct Video: Codable, Identifiable {
    let id: String
    let userId: String
    let videoURL: String
    let thumbnailURL: String
    let duration: Double // max 8.0 seconds
    let caption: String?
    let createdAt: Timestamp
    let likeCount: Int
    let dislikeCount: Int
    let responseCount: Int
    let parentVideoId: String? // nil for original videos, set for responses
    let editedText: String? // Text overlay added during editing
}
```

### Response Model
```swift
struct VideoResponse: Codable, Identifiable {
    let id: String
    let videoId: String // Parent video ID
    let userId: String
    let videoURL: String
    let thumbnailURL: String
    let createdAt: Timestamp
    let likeCount: Int
    let dislikeCount: Int
    let responseCount: Int // For nested responses
}
```

### Like/Dislike Model
```swift
struct Interaction: Codable {
    let userId: String
    let videoId: String
    let type: InteractionType // like, dislike
    let createdAt: Timestamp
}
```

### Follow Model
```swift
struct Follow: Codable {
    let followerId: String
    let followingId: String
    let createdAt: Timestamp
}
```

### Enums
```swift
enum School: String, Codable, CaseIterable {
    case crimsonCliffs = "Crimson Cliffs"
    case desertHills = "Desert Hills"
    case dixie = "Dixie"
    case pineView = "Pine View"
    case snowCanyon = "Snow Canyon"
    case hurricane = "Hurricane"
    case enterprise = "Enterprise"
    case waterCanyon = "Water Canyon"
    case careerTech = "Career Tech"
    case other = "Other"
}

enum Grade: String, Codable, CaseIterable {
    case nine = "9"
    case ten = "10"
    case eleven = "11"
    case twelve = "12"
    case other = "Other"
}
```

---

## Firebase Database Schema

### Firestore Collections

#### `users/{userId}`
- User profile data
- Indexed by: school, grade, createdAt

#### `videos/{videoId}`
- Video metadata
- Indexed by: userId, createdAt, parentVideoId, likeCount

#### `responses/{responseId}`
- Video response metadata
- Indexed by: videoId, createdAt, likeCount

#### `interactions/{interactionId}`
- Like/dislike records
- Indexed by: userId, videoId, type

#### `follows/{followId}`
- Follow relationships
- Indexed by: followerId, followingId

#### `feed/{userId}/videos/{videoId}`
- Personalized feed cache (optional optimization)

---

## Screen Implementation Plan

### 1. Onboarding Flow

#### OnboardingView
**Purpose**: Collect user information and authenticate

**Steps**:
1. **Welcome Screen**
   - App logo and "Welcome to Eight" message
   - "Get Started" button

2. **Google Sign-In Screen**
   - Google Sign-In button
   - Text: "Please use your washk12.org email"
   - Validate email domain before proceeding
   - Error handling for non-washk12.org emails

3. **School Selection Screen**
   - Picker/List with school options:
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
   - "Continue" button

4. **Grade Selection Screen**
   - Picker/List with grade options:
     - 9, 10, 11, 12, Other
   - "Continue" button

5. **Profile Setup Screen**
   - Profile picture upload (optional, can skip)
   - Display name input
   - Bio input (optional)
   - "Complete Setup" button

**Implementation**:
- `OnboardingViewModel` - Manages onboarding state
- `AuthService` - Handles Google Sign-In
- Navigation using `NavigationStack` (iOS 16+)

---

### 2. Main Tab Navigation

#### TabView Structure
```swift
TabView {
    FeedView()
        .tabItem { Label("Feed", systemImage: "house.fill") }
    
    CameraView()
        .tabItem { Label("Camera", systemImage: "camera.fill") }
    
    ProfileView()
        .tabItem { Label("Profile", systemImage: "person.fill") }
}
```

---

### 3. Feed Screen

#### FeedView
**Priority**: Highest - Must be optimized for instant loading

**Features**:
- Vertical scrolling feed of videos
- Like/Dislike buttons (bottom left, semi-transparent)
- Record Response button (bottom right)
- View Responses button (bottom right)
- Auto-play current video
- Pause when scrolling away

**Optimization Strategies**:
1. **LazyVStack**: Only render visible videos
2. **Video Preloading**: Preload next 2-3 videos
3. **Thumbnail First**: Show thumbnail immediately, load video on demand
4. **Video Caching**: Cache videos locally after first play
5. **Pagination**: Load videos in batches (20 at a time)
6. **Background Prefetching**: Prefetch videos when on WiFi
7. **Compression**: Store videos in optimized format (H.264, 720p max)

**Components**:
- `FeedView` - Main container
- `FeedVideoPlayer` - Individual video player component
- `FeedViewModel` - Manages feed data and state
- `VideoPlayerManager` - Handles video playback and caching
- `FeedService` - Fetches feed data from Firestore

**Data Flow**:
1. Fetch followed users
2. Fetch videos from followed users (sorted by createdAt, descending)
3. Load videos lazily as user scrolls
4. Update like counts in real-time via Firestore listeners

---

### 4. Camera Screen

#### CameraView
**Purpose**: Record 8-second videos

**Features**:
- Live camera preview
- Record button (bottom center)
- Zoom control (intuitive slider or pinch gesture)
- 8-second countdown timer (subtle, top or bottom)
- Auto-stop at 8 seconds
- Manual stop before 8 seconds

**Components**:
- `CameraView` - Main camera interface
- `CameraViewModel` - Manages camera session and recording
- `CameraManager` - AVFoundation camera handling
- `RecordingTimerView` - Countdown display

**Implementation Details**:
- Use `AVCaptureSession` for camera access
- `AVCaptureMovieFileOutput` for recording
- Timer to track 8-second limit
- Stop recording automatically at 8 seconds
- Save video to temporary location

**Navigation Flow**:
Camera → Editing → Preview → Post/Cancel

---

### 5. Video Editing Screen

#### VideoEditingView
**Purpose**: Edit recorded video before posting

**Features**:
1. **Cropping**
   - Crop tool with adjustable frame
   - Preview cropped result

2. **Text Overlay**
   - Add text to video
   - Position text (drag to move)
   - Font size and color options
   - Simple text editor

3. **Additional Editing Options** (if time permits):
   - Basic filters (brightness, contrast, saturation)
   - Trim start/end (if video is less than 8 seconds)
   - Speed adjustment (0.5x, 1x, 1.5x)

4. **Preview**
   - Play edited video
   - Loop playback

5. **Actions**
   - "Post" button
   - "Discard" button

**Components**:
- `VideoEditingView` - Main editing interface
- `VideoEditingViewModel` - Manages editing state
- `VideoEditor` - Core Image/AVFoundation editing operations
- `TextOverlayView` - Text editing UI

**Implementation**:
- Use `AVMutableComposition` for video composition
- `CIFilter` for filters
- `CATextLayer` or `AVMutableVideoComposition` for text overlay

---

### 6. Profile Screen

#### ProfileView
**Purpose**: Display user's profile and videos

**Features**:
1. **Profile Header**
   - Profile picture (tappable to edit)
   - Display name
   - Bio (if set)
   - Stats:
     - Friends count (following)
     - Videos posted count
     - Followers count
   - Edit Profile button

2. **Navigation Icons**
   - Settings icon (top right)
   - Search icon (top left or next to settings)

3. **User's Videos Grid**
   - Grid layout of posted videos
   - Tap to view full screen
   - Shows thumbnail with play icon

4. **Additional Features**:
   - Follow/Unfollow button (if viewing other user's profile)
   - Share profile button
   - Block user option (in settings)

**Components**:
- `ProfileView` - Main profile container
- `ProfileHeaderView` - Profile info section
- `ProfileVideoGrid` - Grid of user's videos
- `ProfileViewModel` - Manages profile data

---

### 7. Settings Screen

#### SettingsView
**Purpose**: App and account settings

**Features**:
1. **Account Settings**
   - Edit profile
   - Change profile picture
   - Update bio
   - Change display name

2. **Privacy Settings**
   - Who can see my videos (Everyone, Followers only)
   - Who can respond to my videos
   - Blocked users list

3. **Notifications**
   - Push notification preferences
   - Like/dislike notifications
   - New follower notifications
   - Response notifications

4. **App Settings**
   - Data usage (WiFi only for video)
   - Clear cache
   - App version info

5. **Account Actions**
   - Logout
   - Delete account

---

### 8. Search Screen

#### SearchView
**Purpose**: Find and follow other users

**Features**:
- Search bar
- Filter by school (optional)
- Filter by grade (optional)
- User list with:
  - Profile picture
  - Display name
  - School and grade
  - Follow/Unfollow button
- Tap user to view their profile

**Components**:
- `SearchView` - Main search interface
- `SearchViewModel` - Manages search logic
- `UserSearchResultView` - Individual user result

---

### 9. Video Response Flow

#### ResponseRecordingView
**Purpose**: Record response to a video

**Reuses**: Camera screen code
- Same 8-second recording interface
- Same editing flow
- Posts as response instead of original video

#### ResponsesView
**Purpose**: View responses to a video

**Features**:
- Vertical list of responses
- Sorted by:
  1. Like count (descending)
  2. Created date (descending) - tiebreaker
- Each response shows:
  - Video player
  - Like/Dislike buttons
  - Record Response button (for nested responses)
  - View Responses button (for nested responses)
- Infinite nesting support

**Components**:
- `ResponsesView` - Main responses container
- `ResponseVideoPlayer` - Individual response player
- `ResponsesViewModel` - Manages responses data

---

## Service Layer Architecture

### AuthService
- `signInWithGoogle()` - Google Sign-In
- `validateEmailDomain()` - Check washk12.org
- `signOut()` - Logout
- `getCurrentUser()` - Get authenticated user

### UserService
- `createUser()` - Create new user profile
- `updateUser()` - Update user data
- `getUser()` - Fetch user by ID
- `searchUsers()` - Search users by name/school
- `followUser()` - Follow a user
- `unfollowUser()` - Unfollow a user
- `getFollowers()` - Get user's followers
- `getFollowing()` - Get users being followed

### VideoService
- `uploadVideo()` - Upload video to Firebase Storage
- `createVideo()` - Create video document in Firestore
- `getFeedVideos()` - Get feed videos (optimized query)
- `getUserVideos()` - Get videos by user ID
- `deleteVideo()` - Delete video
- `getVideoResponses()` - Get responses to a video
- `createResponse()` - Create video response

### InteractionService
- `likeVideo()` - Like a video
- `dislikeVideo()` - Dislike a video
- `unlikeVideo()` - Remove like
- `undislikeVideo()` - Remove dislike
- `getUserInteraction()` - Check if user liked/disliked
- `getVideoInteractions()` - Get like/dislike counts

### StorageService
- `uploadVideoFile()` - Upload video to Storage
- `uploadImageFile()` - Upload image to Storage
- `getDownloadURL()` - Get file download URL
- `deleteFile()` - Delete file from Storage

### CacheService
- `cacheVideo()` - Cache video locally
- `getCachedVideo()` - Retrieve cached video
- `clearCache()` - Clear all cached data
- `preloadVideos()` - Preload videos for feed

---

## Performance Optimization Strategy

### Feed Optimization (Priority #1)

1. **Video Compression**
   - Compress videos to 720p max resolution
   - H.264 codec for compatibility
   - Target file size: < 5MB per 8-second video
   - Use `AVAssetExportSession` for compression

2. **Lazy Loading**
   - Only load videos when they're about to enter viewport
   - Use `LazyVStack` with proper spacing
   - Load thumbnails first, then videos

3. **Preloading Strategy**
   - Preload next 2-3 videos in background
   - Preload on WiFi only (configurable)
   - Cancel preload if user scrolls away quickly

4. **Caching**
   - Cache videos after first play
   - Cache thumbnails immediately
   - Use NSCache for in-memory caching
   - Disk cache for persistent storage
   - LRU eviction policy

5. **Database Optimization**
   - Index Firestore queries properly
   - Use composite indexes for feed queries
   - Paginate results (20 videos per page)
   - Use Firestore listeners for real-time updates (efficient)

6. **Video Player Optimization**
   - Reuse `AVPlayer` instances
   - Preload video buffers
   - Pause videos not in viewport
   - Release resources when video is far from viewport

7. **Network Optimization**
   - Use CDN for video delivery (Firebase Storage)
   - Implement adaptive bitrate (if possible)
   - Compress API responses
   - Batch Firestore reads when possible

---

## Development Phases

### Phase 1: Foundation & Setup (Week 1-2)
- [ ] Project setup and Firebase configuration
- [ ] Google Sign-In integration
- [ ] Basic navigation structure (TabView)
- [ ] Data models implementation
- [ ] Firebase services setup
- [ ] Basic authentication flow

### Phase 2: Onboarding (Week 2-3)
- [ ] Onboarding UI screens
- [ ] School and grade selection
- [ ] Profile setup
- [ ] User creation in Firestore

### Phase 3: Camera & Recording (Week 3-4)
- [ ] Camera access and preview
- [ ] Video recording (8-second limit)
- [ ] Countdown timer
- [ ] Zoom controls
- [ ] Basic video editing (cropping, text)
- [ ] Video preview and posting

### Phase 4: Profile Screen (Week 4-5)
- [ ] Profile view implementation
- [ ] Profile picture upload/edit
- [ ] User stats display
- [ ] User's videos grid
- [ ] Settings screen
- [ ] Search functionality

### Phase 5: Feed Screen (Week 5-7) - **CRITICAL**
- [ ] Feed view structure
- [ ] Video player implementation
- [ ] Like/dislike functionality
- [ ] Feed data fetching
- [ ] **Performance optimization**:
  - Lazy loading
  - Video preloading
  - Caching implementation
  - Database query optimization
- [ ] Real-time updates

### Phase 6: Video Responses (Week 7-8)
- [ ] Response recording (reuse camera code)
- [ ] Responses view
- [ ] Nested responses support
- [ ] Response sorting (likes + recency)
- [ ] Response interactions (like/dislike)

### Phase 7: Polish & Optimization (Week 8-9)
- [ ] UI/UX refinements
- [ ] Performance testing and optimization
- [ ] Error handling
- [ ] Loading states
- [ ] Offline support (if time permits)
- [ ] Analytics integration

### Phase 8: Testing & Deployment (Week 9-10)
- [ ] Unit tests
- [ ] UI tests
- [ ] Beta testing with target users
- [ ] Bug fixes
- [ ] App Store preparation
- [ ] Submission

---

## Firebase Setup Checklist

### Firebase Project Setup
- [ ] Create Firebase project
- [ ] Add iOS app to project
- [ ] Download `GoogleService-Info.plist`
- [ ] Add to Xcode project

### Authentication
- [ ] Enable Google Sign-In in Firebase Console
- [ ] Configure OAuth consent screen
- [ ] Add washk12.org domain validation
- [ ] Set up email domain restrictions

### Firestore
- [ ] Create database
- [ ] Set up security rules
- [ ] Create indexes:
  - `videos`: userId, createdAt
  - `videos`: parentVideoId, likeCount, createdAt
  - `users`: school, grade
  - `follows`: followerId, followingId
  - `interactions`: userId, videoId

### Storage
- [ ] Create Storage bucket
- [ ] Set up security rules
- [ ] Configure CORS (if needed)
- [ ] Set up lifecycle rules (optional cleanup)

### Security Rules
```javascript
// Firestore Rules (example)
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read any user, but only update their own
    match /users/{userId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Videos: read any, write own
    match /videos/{videoId} {
      allow read: if true;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth != null && 
                               resource.data.userId == request.auth.uid;
    }
    
    // Similar rules for responses, interactions, follows
  }
}
```

---

## Additional Features & Considerations

### Suggested Enhancements
1. **Push Notifications**
   - New follower notifications
   - Like/dislike notifications
   - Response notifications
   - Use Firebase Cloud Messaging

2. **Analytics**
   - Track video views
   - User engagement metrics
   - Performance monitoring

3. **Content Moderation** (Future)
   - Report inappropriate content
   - Admin moderation tools
   - Automated content filtering

4. **Social Features**
   - Share videos externally
   - Direct messages (future)
   - Video reactions (beyond like/dislike)

5. **Accessibility**
   - VoiceOver support
   - Dynamic Type support
   - High contrast mode

### Error Handling
- Network errors
- Authentication errors
- Video upload failures
- Camera permission denials
- Storage quota exceeded
- Invalid video format

### Edge Cases
- User deletes account (handle orphaned videos)
- User blocks another user
- Video fails to upload
- App goes to background during recording
- Low storage space
- Poor network conditions

---

## Testing Strategy

### Unit Tests
- ViewModels
- Services
- Data models
- Utility functions

### UI Tests
- Onboarding flow
- Camera recording
- Video posting
- Feed scrolling
- Like/dislike interactions
- Response recording

### Performance Tests
- Feed loading time
- Video playback smoothness
- Memory usage
- Battery consumption
- Network usage

### User Acceptance Testing
- Beta test with 10-20 students
- Collect feedback
- Iterate on UX issues

---

## Deployment Checklist

### Pre-Launch
- [ ] Complete all features
- [ ] Fix all critical bugs
- [ ] Performance optimization complete
- [ ] Security review
- [ ] Privacy policy created
- [ ] Terms of service created
- [ ] App Store assets prepared:
  - App icon
  - Screenshots
  - App description
  - Keywords
  - Privacy policy URL

### App Store Submission
- [ ] App Store Connect setup
- [ ] Build uploaded
- [ ] TestFlight beta testing
- [ ] App Store review submission
- [ ] Monitor review status

### Post-Launch
- [ ] Monitor crash reports
- [ ] Track analytics
- [ ] Collect user feedback
- [ ] Plan updates and improvements

---

## Notes & Considerations

1. **8-Second Limit**: This is core to the app's identity. Ensure this is enforced at multiple levels (UI, validation, backend).

2. **School-Specific**: Since this is for Washington County schools, consider adding school-specific features later (school events, announcements, etc.).

3. **Scalability**: Design with growth in mind. The architecture should handle increasing user base.

4. **Privacy**: Ensure compliance with COPPA and other privacy regulations for minors.

5. **Content Policy**: Establish clear content guidelines and moderation strategy.

6. **Performance Monitoring**: Use Firebase Performance Monitoring to track app performance in production.

---

## Resources & Documentation

### Official Documentation
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [AVFoundation Documentation](https://developer.apple.com/documentation/avfoundation)
- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [Google Sign-In iOS](https://developers.google.com/identity/sign-in/ios)

### Key SwiftUI Patterns
- `@State`, `@Binding`, `@StateObject`, `@ObservedObject`
- `@EnvironmentObject` for shared state
- `NavigationStack` for navigation
- `LazyVStack` for efficient lists
- `AsyncImage` for image loading

### Firebase Best Practices
- Use Firestore listeners for real-time updates
- Implement proper pagination
- Use composite indexes for complex queries
- Optimize security rules
- Use Storage rules for file access control

---

## Conclusion

This development plan provides a comprehensive roadmap for building "Eight". The architecture prioritizes feed performance while maintaining clean, maintainable code. The phased approach allows for iterative development and testing.

**Key Success Factors**:
1. Feed optimization is the top priority
2. Clean, modular architecture
3. Thorough testing at each phase
4. User feedback integration
5. Performance monitoring

Good luck with the development! 🚀
