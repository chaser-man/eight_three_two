//
//  FeedViewModel.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class FeedViewModel: ObservableObject {
    @Published var feedVideos: [Video] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let videoService = VideoService()
    private let userService = UserService()
    private var followingUserIds: [String] = []
    private var lastDocument: DocumentSnapshot?
    private var preloadTask: Task<Void, Never>?
    
    // Video cache
    private var videoCache: [String: URL] = [:]
    private let cacheDirectory: URL
    
    init() {
        // Setup cache directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("VideoCache")
        
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load ALL videos (not just from followed users)
            let result = try await videoService.getAllVideos()
            feedVideos = result.videos
            lastDocument = result.lastDocument
            
            print("✅ Loaded \(feedVideos.count) videos in feed")
            if feedVideos.isEmpty {
                print("⚠️ No videos found in database")
            }
            
            // Preloading will happen automatically when user scrolls (via preloadAdjacentVideos)
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error loading feed: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func refreshFeed() async {
        lastDocument = nil
        feedVideos = []
        videoCache.removeAll()
        await loadFeed()
    }
    
    func loadMoreVideos() async {
        guard !isLoading, let lastDoc = lastDocument else { return }
        
        isLoading = true
        do {
            let result = try await videoService.getAllVideos(lastDocument: lastDoc)
            feedVideos.append(contentsOf: result.videos)
            lastDocument = result.lastDocument
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func preloadAdjacentVideos(currentIndex: Int) {
        preloadTask?.cancel()
        preloadTask = Task {
            // Preload next 2 videos
            for i in (currentIndex + 1)..<min(currentIndex + 3, feedVideos.count) {
                guard !Task.isCancelled else { return }
                let video = feedVideos[i]
                await preloadVideo(video: video)
            }
        }
    }
    
    func preloadVideo(video: Video) async {
        // Check if already cached
        if getCachedVideoURL(videoId: video.id) != nil {
            return
        }
        
        guard let url = URL(string: video.videoURL) else { return }
        
        // Download and cache video
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let cachedURL = cacheDirectory.appendingPathComponent("\(video.id).mp4")
            try data.write(to: cachedURL)
            videoCache[video.id] = cachedURL
        } catch {
            print("Error preloading video: \(error)")
        }
    }
    
    func cacheVideo(videoId: String, url: URL) {
        // Cache is handled by preloadVideo
        // This is called when video is first played
        Task {
            await preloadVideo(video: Video(
                id: videoId,
                userId: "",
                videoURL: url.absoluteString,
                thumbnailURL: "",
                duration: 0
            ))
        }
    }
    
    func getCachedVideoURL(videoId: String) -> URL? {
        if let cachedURL = videoCache[videoId] {
            return cachedURL
        }
        
        let cachedURL = cacheDirectory.appendingPathComponent("\(videoId).mp4")
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            videoCache[videoId] = cachedURL
            return cachedURL
        }
        
        return nil
    }
    
    func refreshVideo(videoId: String) async {
        do {
            if let updatedVideo = try await videoService.getVideo(videoId: videoId) {
                if let index = feedVideos.firstIndex(where: { $0.id == videoId }) {
                    let oldCount = feedVideos[index].likeCount
                    let newCount = updatedVideo.likeCount
                    print("🔄 Refreshing video \(videoId): likeCount \(oldCount) -> \(newCount)")
                    // Update the video in the array - this will trigger SwiftUI to update the view
                    feedVideos[index] = updatedVideo
                } else {
                    print("⚠️ Video \(videoId) not found in feedVideos array")
                }
            } else {
                print("⚠️ Could not fetch updated video \(videoId) from Firestore")
            }
        } catch {
            print("❌ Error refreshing video \(videoId): \(error)")
        }
    }
}
