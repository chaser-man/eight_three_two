//
//  FeedView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI
import AVKit
import FirebaseAuth
import Combine

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var currentIndex: Int? = 0
    
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
                            viewModel: viewModel
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
    @State private var player: AVPlayer?
    @State private var showingWaves = false
    @State private var showingWaveRecording = false
    @State private var userInteraction: InteractionType?
    
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
            
            // Overlay Controls
            VStack {
                Spacer()
                
                HStack {
                    // Left side - Like button only (moved down to where dislike was)
                    Button(action: {
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
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 90) // Positioned where dislike was (30 original + 20 spacing + ~40 for button), with extra to clear tab bar
                    
                    Spacer()
                    
                    // Right side - Wave buttons (moved up)
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
                    .padding(.bottom, 90) // Increased padding to move buttons up and clear tab bar
                }
            }
        }
        .fullScreenCover(isPresented: $showingWaves) {
            ResponsesView(videoId: video.id)
        }
        .fullScreenCover(isPresented: $showingWaveRecording) {
            ResponseRecordingView(parentVideoId: video.id)
        }
        .task {
            await checkUserInteraction()
        }
        .onChange(of: isActive) { active in
            if active && player == nil {
                loadVideo()
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
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else { 
            print("❌ No user ID available for like action")
            return 
        }
        
        let interactionService = InteractionService()
        let wasLiked = userInteraction == .like
        
        print("🔄 Toggle like - wasLiked: \(wasLiked), videoId: \(video.id)")
        
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
                try await interactionService.likeVideo(userId: userId, videoId: video.id)
                print("✅ likeVideo succeeded")
            }
            
            // Wait a moment for Firestore to propagate, then refresh to get accurate count
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            print("🔄 Refreshing video from Firestore...")
            await viewModel.refreshVideo(videoId: video.id)
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
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        
        let interactionService = InteractionService()
        if let interaction = try? await interactionService.getInteraction(userId: userId, videoId: video.id) {
            userInteraction = interaction.type
        }
    }
}
