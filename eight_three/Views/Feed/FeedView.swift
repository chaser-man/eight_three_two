//
//  FeedView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI
import AVKit
import FirebaseAuth
import FirebaseFirestore
import Combine

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var currentIndex: Int? = 0
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationStack {
            feedContent
                .navigationBarHidden(true)
                .task {
                    await viewModel.loadFeed()
                }
                .refreshable {
                    await viewModel.refreshFeed()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VideoPosted"))) { _ in
                    Task {
                        await viewModel.refreshFeed()
                    }
                }
        }
    }
    
    @ViewBuilder
    private var feedContent: some View {
        if viewModel.isLoading && viewModel.feedVideos.isEmpty {
            loadingView
        } else if viewModel.feedVideos.isEmpty {
            emptyStateView
        } else {
            videoFeedView
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading feed...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No videos yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Be the first to post a video!")
                .font(.body)
                .foregroundColor(.secondary)
            if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
    
    private var videoFeedView: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.feedVideos.enumerated()), id: \.element.id) { index, video in
                        FeedVideoPlayer(
                            video: video,
                            isActive: index == (currentIndex ?? 0),
                            viewModel: viewModel,
                            authService: authService
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentIndex)
            .onChange(of: currentIndex) { oldValue, newValue in
                if let newIndex = newValue {
                    viewModel.preloadAdjacentVideos(currentIndex: newIndex)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Initialize currentIndex to 0 when view appears
            if currentIndex == nil {
                currentIndex = 0
            }
        }
    }
}

struct FeedVideoPlayer: View {
    let video: Video
    let isActive: Bool
    @ObservedObject var viewModel: FeedViewModel
    @ObservedObject var authService: AuthService
    @State private var player: AVPlayer?
    @State private var showingWaves = false
    @State private var showingWaveRecording = false
    @State private var userInteraction: InteractionType?
    @State private var videoUser: User?
    @State private var showingUserProfile = false
    
    private let userService = UserService()
    
    // Get the current video from viewModel to ensure we always have the latest data
    private var currentVideo: Video {
        viewModel.feedVideos.first(where: { $0.id == video.id }) ?? video
    }
    
    var body: some View {
        ZStack {
            // Video Player
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .allowsHitTesting(false) // Allow touches to pass through to overlay buttons
                    .ignoresSafeArea()
                    .onAppear {
                        if isActive {
                            player.play()
                        }
                    }
                    .onDisappear {
                        player.pause()
                    }
                    .onChange(of: isActive) { active in
                        if active {
                            player.play()
                        } else {
                            player.pause()
                        }
                    }
            } else {
                // Thumbnail while loading
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.black)
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                }
                .ignoresSafeArea()
                .onAppear {
                    if isActive {
                        loadVideo()
                    }
                }
            }
            
            // Overlay Controls - ensure this is on top and can receive touches
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
                    // Left side - Like button and profile section
                    VStack(spacing: 12) {
                        // Like button (moved up to be parallel with Record Wave)
                        Button(action: {
                            print("🔘 Like button tapped! videoId: \(video.id)")
                            Task {
                                await toggleLike()
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: userInteraction == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .font(.system(size: 30))
                                    .foregroundColor(userInteraction == .like ? .blue : .white)
                                Text("\(currentVideo.likeCount)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                            .contentShape(Rectangle()) // Ensure entire button area is tappable
                        }
                        .buttonStyle(PlainButtonStyle()) // Use plain style to avoid default button behavior
                        
                        // Profile picture and name section
                        if let user = videoUser {
                            Button(action: {
                                showingUserProfile = true
                            }) {
                                VStack(spacing: 6) {
                                    // Profile picture
                                    if let profilePictureURL = user.profilePictureURL,
                                       let url = URL(string: profilePictureURL) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            Circle()
                                                .fill(Color.gray.opacity(0.5))
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .foregroundColor(.white)
                                                        .font(.system(size: 20))
                                                )
                                        }
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.5))
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 20))
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                    }
                                    
                                    // User name
                                    Text(user.displayName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .frame(maxWidth: 70)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(12)
                            }
                        } else {
                            // Loading placeholder
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.7)
                                    )
                                Text("Loading...")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 90) // Match the right side padding to align with Record Wave button
                    
                    Spacer()
                    
                    // Right side - Wave buttons
                    VStack(spacing: 20) {
                        Button(action: {
                            showingWaveRecording = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                Text("Record Wave")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            showingWaves = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "bubble.right.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                Text("\(currentVideo.responseCount)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Text("View Waves")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 90) // Keep same padding as before
                }
            }
            .allowsHitTesting(true) // Ensure overlay can receive touches
        }
        .fullScreenCover(isPresented: $showingWaves) {
            ResponsesView(videoId: video.id)
        }
        .fullScreenCover(isPresented: $showingWaveRecording) {
            ResponseRecordingView(parentVideoId: video.id)
        }
        .sheet(isPresented: $showingUserProfile) {
            if let user = videoUser {
                NavigationStack {
                    UserProfileView(user: user)
                        .environmentObject(authService)
                }
            }
        }
        .task {
            await checkUserInteraction()
            await loadUserData()
        }
        .onChange(of: isActive) { active in
            if active && player == nil {
                loadVideo()
            }
            if active && videoUser == nil {
                Task {
                    await loadUserData()
                }
            }
            if active {
                // Re-check interaction state when video becomes active
                Task {
                    await checkUserInteraction()
                }
            }
        }
    }
    
    private func loadVideo() {
        guard player == nil else { return }
        
        // Preload video if available in cache, otherwise load from URL
        if let cachedURL = viewModel.getCachedVideoURL(videoId: video.id) {
            player = AVPlayer(url: cachedURL)
        } else {
            guard let url = URL(string: video.videoURL) else { return }
            player = AVPlayer(url: url)
            // Cache the video in background
            Task {
                await viewModel.preloadVideo(video: video)
            }
        }
        
        player?.isMuted = false
        player?.actionAtItemEnd = .none
        
        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }
    
    private func toggleLike() async {
        print("🚀 toggleLike() called for video: \(video.id)")
        
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else { 
            print("❌ No user ID available for like action")
            return 
        }
        
        print("✅ User ID found: \(userId)")
        
        let interactionService = InteractionService()
        
        // First, check the actual state in Firestore to ensure we're in sync
        let actualInteraction: InteractionType?
        do {
            print("🔍 Checking Firestore for existing interaction...")
            if let interaction = try await interactionService.getInteraction(userId: userId, videoId: video.id) {
                actualInteraction = interaction.type
                print("✅ Found interaction in Firestore: \(interaction.type.rawValue)")
            } else {
                actualInteraction = nil
                print("ℹ️ No interaction found in Firestore")
            }
        } catch {
            print("⚠️ Error checking interaction state, using local state: \(error.localizedDescription)")
            print("Error details: \(error)")
            // Fall back to local state if Firestore check fails
            actualInteraction = userInteraction
        }
        
        let wasLiked = actualInteraction == .like
        print("🔄 Toggle like - wasLiked: \(wasLiked), videoId: \(video.id), localState: \(userInteraction?.rawValue ?? "nil"), actualState: \(actualInteraction?.rawValue ?? "nil")")
        
        // Optimistic UI update - immediately update the local count and state
        // Update state first on main thread to ensure UI updates immediately
        await MainActor.run {
            if wasLiked {
                userInteraction = nil
            } else {
                userInteraction = .like
            }
        }
        
        if let index = viewModel.feedVideos.firstIndex(where: { $0.id == video.id }) {
            var updatedVideo = viewModel.feedVideos[index]
            if wasLiked {
                // Unliking - decrement count
                updatedVideo.likeCount = max(0, updatedVideo.likeCount - 1)
                print("👍 Optimistic update: Unliking - count: \(updatedVideo.likeCount)")
            } else {
                // Liking - increment count
                updatedVideo.likeCount += 1
                print("👍 Optimistic update: Liking - count: \(updatedVideo.likeCount)")
            }
            // Update the array to trigger SwiftUI change notification
            await MainActor.run {
                viewModel.feedVideos[index] = updatedVideo
            }
        } else {
            print("⚠️ Video not found in feedVideos array")
        }
        
        // Perform the actual like/unlike action
        do {
            if wasLiked {
                print("📤 Calling unlikeVideo...")
                try await interactionService.unlikeVideo(userId: userId, videoId: video.id)
                print("✅ unlikeVideo succeeded")
            } else {
                print("📤 Calling likeVideo...")
                // Use a direct approach - create the interaction document directly
                // This avoids the toggle logic in likeVideo
                let db = Firestore.firestore()
                let likeInteractionId = "\(userId)_\(video.id)_like"
                let dislikeInteractionId = "\(userId)_\(video.id)_dislike"
                
                // First, check if there's a dislike and remove it if present
                let dislikeDoc = try await db.collection("interactions").document(dislikeInteractionId).getDocument()
                if dislikeDoc.exists {
                    try await db.collection("interactions").document(dislikeInteractionId).delete()
                    // Decrement dislike count
                    try await db.collection("videos").document(video.id).updateData([
                        "dislikeCount": FieldValue.increment(Int64(-1))
                    ])
                    print("✅ Removed existing dislike before adding like")
                }
                
                // Check if like interaction already exists
                let likeDoc = try await db.collection("interactions").document(likeInteractionId).getDocument()
                if !likeDoc.exists {
                    // Create the like interaction
                    let interactionData: [String: Any] = [
                        "id": likeInteractionId,
                        "userId": userId,
                        "videoId": video.id,
                        "type": InteractionType.like.rawValue,
                        "createdAt": Timestamp()
                    ]
                    try await db.collection("interactions").document(likeInteractionId).setData(interactionData)
                    // Update like count
                    try await db.collection("videos").document(video.id).updateData([
                        "likeCount": FieldValue.increment(Int64(1))
                    ])
                    print("✅ likeVideo succeeded (direct method)")
                } else {
                    print("⚠️ Like already exists, skipping")
                }
            }
            
            // Update userInteraction state after successful operation
            await MainActor.run {
                if wasLiked {
                    userInteraction = nil
                } else {
                    userInteraction = .like
                }
            }
            
            // Wait a moment for Firestore to propagate, then refresh to get accurate count
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            print("🔄 Refreshing video from Firestore...")
            await viewModel.refreshVideo(videoId: video.id)
            
            // Re-check interaction state to ensure sync
            await checkUserInteraction()
        } catch {
            // If the update failed, revert the optimistic update
            print("❌ Error updating like: \(error.localizedDescription)")
            print("🔄 Reverting optimistic update...")
            if let index = viewModel.feedVideos.firstIndex(where: { $0.id == video.id }) {
                var revertedVideo = viewModel.feedVideos[index]
                if wasLiked {
                    // Revert: add back the like we removed
                    revertedVideo.likeCount += 1
                    print("↩️ Reverted: Added like back")
                } else {
                    // Revert: remove the like we added
                    revertedVideo.likeCount = max(0, revertedVideo.likeCount - 1)
                    print("↩️ Reverted: Removed like")
                }
                await MainActor.run {
                    viewModel.feedVideos[index] = revertedVideo
                    if wasLiked {
                        userInteraction = .like
                    } else {
                        userInteraction = nil
                    }
                }
            }
        }
    }
    
    private func checkUserInteraction() async {
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else { 
            print("⚠️ No user ID available for checking interaction")
            return 
        }
        
        let interactionService = InteractionService()
        do {
            if let interaction = try await interactionService.getInteraction(userId: userId, videoId: video.id) {
                await MainActor.run {
                    userInteraction = interaction.type
                    print("✅ Updated userInteraction state: \(interaction.type.rawValue) for video \(video.id)")
                }
            } else {
                await MainActor.run {
                    userInteraction = nil
                    print("✅ No interaction found for video \(video.id), set to nil")
                }
            }
        } catch {
            print("❌ Error checking user interaction: \(error.localizedDescription)")
            // Don't update state if there's an error - keep current state
        }
    }
    
    private func loadUserData() async {
        // Only load if we don't already have the user data
        guard videoUser == nil else { return }
        
        do {
            if let user = try await userService.getUser(userId: video.userId) {
                await MainActor.run {
                    videoUser = user
                }
            }
        } catch {
            print("Error loading user data: \(error.localizedDescription)")
        }
    }
}
