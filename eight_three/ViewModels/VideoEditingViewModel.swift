//
//  VideoEditingViewModel.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import SwiftUI
import AVFoundation
import AVKit
import UIKit
import FirebaseAuth

@MainActor
class VideoEditingViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var editedVideoURL: URL?
    @Published var isPosting = false
    @Published var errorMessage: String?
    
    private let videoService = VideoService()
    private let storageService = StorageService()
    
    func loadVideo(url: URL) async {
        // Retry logic for loading video (in case file isn't fully written yet)
        var retries = 3
        var lastError: Error?
        
        while retries > 0 {
            // Verify file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                if retries > 1 {
                    // Wait a bit and retry
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    retries -= 1
                    continue
                } else {
                    errorMessage = "Video file not found"
                    return
                }
            }
            
            // Check file size to ensure it's not empty
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let fileSize = attributes[.size] as? Int64, fileSize < 1000 {
                if retries > 1 {
                    // File exists but is too small, wait and retry
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    retries -= 1
                    continue
                } else {
                    errorMessage = "Video file is invalid or incomplete"
                    return
                }
            }
            
            // Create asset and load its duration to ensure it's valid
            let asset = AVAsset(url: url)
            
            // Load duration to verify the asset is valid
            do {
                let duration = try await asset.load(.duration)
                guard duration.seconds > 0 else {
                    if retries > 1 {
                        // Duration is 0, wait and retry
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        retries -= 1
                        continue
                    } else {
                        errorMessage = "Invalid video file"
                        return
                    }
                }
                
                // Success - create player with the video asset
                let playerItem = AVPlayerItem(asset: asset)
                player = AVPlayer(playerItem: playerItem)
                
                // Wait for player item to be ready
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                return // Success, exit function
                
            } catch {
                lastError = error
                if retries > 1 {
                    // Wait and retry
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    retries -= 1
                    continue
                } else {
                    errorMessage = "Failed to load video: \(error.localizedDescription)"
                    return
                }
            }
        }
        
        // If we get here, all retries failed
        if let error = lastError {
            errorMessage = "Failed to load video after retries: \(error.localizedDescription)"
        } else {
            errorMessage = "Failed to load video: File not ready"
        }
    }
    
    func postResponse(originalURL: URL, parentVideoId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isPosting = true
        errorMessage = nil
        
        do {
            // No text overlay - use original video
            let finalVideoURL = originalURL
            
            let thumbnail = try await generateThumbnail(from: finalVideoURL)
            let videoId = UUID().uuidString
            
            let videoURL = try await storageService.uploadVideo(
                url: finalVideoURL,
                userId: userId,
                videoId: videoId
            )
            
            let thumbnailURL = try await storageService.uploadThumbnail(
                image: thumbnail,
                userId: userId,
                videoId: videoId
            )
            
            let asset = AVAsset(url: finalVideoURL)
            let duration = try await asset.load(.duration).seconds
            
            let video = Video(
                id: videoId,
                userId: userId,
                videoURL: videoURL,
                thumbnailURL: thumbnailURL,
                duration: duration,
                parentVideoId: parentVideoId,
                editedText: nil
            )
            
            try await videoService.uploadVideo(video)
            try await videoService.incrementResponseCount(videoId: parentVideoId)
            
            isPosting = false
        } catch {
            isPosting = false
            errorMessage = error.localizedDescription
        }
    }
    
    func postVideo(originalURL: URL) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isPosting = true
        errorMessage = nil
        
        do {
            // No text overlay - use original video
            let finalVideoURL = originalURL
            
            // Generate thumbnail from final video
            let thumbnail = try await generateThumbnail(from: finalVideoURL)
            
            // Upload video
            let videoURL = try await storageService.uploadVideo(
                url: finalVideoURL,
                userId: userId,
                videoId: UUID().uuidString
            )
            
            // Upload thumbnail
            let thumbnailURL = try await storageService.uploadThumbnail(
                image: thumbnail,
                userId: userId,
                videoId: UUID().uuidString
            )
            
            // Get video duration
            let asset = AVAsset(url: finalVideoURL)
            let duration = try await asset.load(.duration).seconds
            
            // Create video document
            let video = Video(
                id: UUID().uuidString,
                userId: userId,
                videoURL: videoURL,
                thumbnailURL: thumbnailURL,
                duration: duration,
                editedText: nil
            )
            
            try await videoService.uploadVideo(video)
            
            isPosting = false
        } catch {
            isPosting = false
            errorMessage = error.localizedDescription
        }
    }
    
    
    private func generateThumbnail(from url: URL) async throws -> UIImage {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        let cgImage = try await imageGenerator.image(at: time).image
        
        return UIImage(cgImage: cgImage)
    }
}
