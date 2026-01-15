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
    @Published var overlayText: String = ""
    @Published var fontSize: CGFloat = 48
    @Published var textColor: Color = .white
    @Published var editedVideoURL: URL?
    @Published var isPosting = false
    @Published var errorMessage: String?
    
    private let videoService = VideoService()
    private let storageService = StorageService()
    
    // Font size range
    let minFontSize: CGFloat = 24
    let maxFontSize: CGFloat = 96
    
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
    
    func applyEdits() async {
        // Get the original video URL from the player's asset
        guard let playerItem = player?.currentItem,
              let asset = playerItem.asset as? AVURLAsset else {
            return
        }
        
        let originalURL = asset.url
        
        // Create composition
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return
        }
        
        do {
            let sourceAsset = AVAsset(url: originalURL)
            let videoTracks = try await sourceAsset.loadTracks(withMediaType: AVMediaType.video)
            let audioTracks = try await sourceAsset.loadTracks(withMediaType: AVMediaType.audio)
            
            guard let sourceVideoTrack = videoTracks.first,
                  let sourceAudioTrack = audioTracks.first else {
                return
            }
            
            // Get time range - these properties are available synchronously
            let timeRange = sourceVideoTrack.timeRange
            
            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
            try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)
            
            // Add text overlay if provided
            if !overlayText.isEmpty {
                let videoComposition = AVMutableVideoComposition()
                // These properties are available synchronously
                let naturalSize = sourceVideoTrack.naturalSize
                videoComposition.renderSize = naturalSize
                videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = timeRange
                
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                let preferredTransform = sourceVideoTrack.preferredTransform
                layerInstruction.setTransform(preferredTransform, at: .zero)
                instruction.layerInstructions = [layerInstruction]
                
                videoComposition.instructions = [instruction]
                
                // Add text layer
                let parentLayer = CALayer()
                let videoLayer = CALayer()
                parentLayer.frame = CGRect(origin: .zero, size: videoComposition.renderSize)
                videoLayer.frame = parentLayer.frame
                parentLayer.addSublayer(videoLayer)
                
                if !overlayText.isEmpty {
                    let textLayer = CATextLayer()
                    textLayer.string = overlayText
                    textLayer.fontSize = fontSize
                    // Convert SwiftUI Color to UIColor
                    let uiColor = UIColor(textColor)
                    textLayer.foregroundColor = uiColor.cgColor
                    textLayer.alignmentMode = .center
                    
                    // Calculate text layer height based on font size
                    let textHeight = fontSize * 1.5
                    textLayer.frame = CGRect(
                        x: 0,
                        y: videoComposition.renderSize.height - textHeight - 20,
                        width: videoComposition.renderSize.width,
                        height: textHeight
                    )
                    textLayer.isWrapped = true
                    parentLayer.addSublayer(textLayer)
                }
                
                videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                    postProcessingAsVideoLayer: videoLayer,
                    in: parentLayer
                )
                
                // Export
                let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
                exportSession?.videoComposition = videoComposition
                
                let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("edited_\(UUID().uuidString).mp4")
                try? FileManager.default.removeItem(at: outputURL)
                
                exportSession?.outputURL = outputURL
                exportSession?.outputFileType = .mp4
                
                await exportSession?.export()
                
                if exportSession?.status == .completed {
                    editedVideoURL = outputURL
                    player = AVPlayer(url: outputURL)
                }
            } else {
                editedVideoURL = originalURL
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func postResponse(originalURL: URL, parentVideoId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isPosting = true
        errorMessage = nil
        
        do {
            // Apply edits first if there's text overlay
            var finalVideoURL = originalURL
            if !overlayText.isEmpty {
                await applyEditsToURL(originalURL: originalURL)
                if let edited = editedVideoURL {
                    finalVideoURL = edited
                }
            }
            
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
                editedText: overlayText.isEmpty ? nil : overlayText
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
            // Apply edits first if there's text overlay
            var finalVideoURL = originalURL
            if !overlayText.isEmpty {
                // Get the original video URL from the player's asset
                guard let playerItem = player?.currentItem,
                      let asset = playerItem.asset as? AVURLAsset else {
                    errorMessage = "Failed to get video asset"
                    isPosting = false
                    return
                }
                
                let editedURL = asset.url
                await applyEditsToURL(originalURL: editedURL)
                
                if let edited = editedVideoURL {
                    finalVideoURL = edited
                }
            }
            
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
                editedText: overlayText.isEmpty ? nil : overlayText
            )
            
            try await videoService.uploadVideo(video)
            
            isPosting = false
        } catch {
            isPosting = false
            errorMessage = error.localizedDescription
        }
    }
    
    private func applyEditsToURL(originalURL: URL) async {
        // Create composition
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return
        }
        
        do {
            let sourceAsset = AVAsset(url: originalURL)
            let videoTracks = try await sourceAsset.loadTracks(withMediaType: AVMediaType.video)
            let audioTracks = try await sourceAsset.loadTracks(withMediaType: AVMediaType.audio)
            
            guard let sourceVideoTrack = videoTracks.first,
                  let sourceAudioTrack = audioTracks.first else {
                return
            }
            
            // Get time range
            let timeRange = sourceVideoTrack.timeRange
            
            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
            try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)
            
            // Add text overlay if provided
            if !overlayText.isEmpty {
                let videoComposition = AVMutableVideoComposition()
                let naturalSize = sourceVideoTrack.naturalSize
                videoComposition.renderSize = naturalSize
                videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = timeRange
                
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                let preferredTransform = sourceVideoTrack.preferredTransform
                layerInstruction.setTransform(preferredTransform, at: .zero)
                instruction.layerInstructions = [layerInstruction]
                
                videoComposition.instructions = [instruction]
                
                // Add text layer
                let parentLayer = CALayer()
                let videoLayer = CALayer()
                parentLayer.frame = CGRect(origin: .zero, size: videoComposition.renderSize)
                videoLayer.frame = parentLayer.frame
                parentLayer.addSublayer(videoLayer)
                
                let textLayer = CATextLayer()
                textLayer.string = overlayText
                textLayer.fontSize = fontSize
                let uiColor = UIColor(textColor)
                textLayer.foregroundColor = uiColor.cgColor
                textLayer.alignmentMode = .center
                
                let textHeight = fontSize * 1.5
                textLayer.frame = CGRect(
                    x: 0,
                    y: videoComposition.renderSize.height - textHeight - 20,
                    width: videoComposition.renderSize.width,
                    height: textHeight
                )
                textLayer.isWrapped = true
                parentLayer.addSublayer(textLayer)
                
                videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                    postProcessingAsVideoLayer: videoLayer,
                    in: parentLayer
                )
                
                // Export
                let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
                exportSession?.videoComposition = videoComposition
                
                let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("edited_\(UUID().uuidString).mp4")
                try? FileManager.default.removeItem(at: outputURL)
                
                exportSession?.outputURL = outputURL
                exportSession?.outputFileType = .mp4
                
                await exportSession?.export()
                
                if exportSession?.status == .completed {
                    editedVideoURL = outputURL
                }
            } else {
                editedVideoURL = originalURL
            }
        } catch {
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
