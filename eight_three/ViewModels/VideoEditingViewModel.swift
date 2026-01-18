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

// Text overlay properties
struct TextOverlay: Codable {
    var text: String
    var positionX: Double // Normalized 0.0 to 1.0
    var positionY: Double // Normalized 0.0 to 1.0
    var fontSize: Double
    var color: TextColor
    var alignment: TextAlignment
    
    enum TextColor: String, Codable {
        case white, black, red, blue, yellow, green
        
        var uiColor: UIColor {
            switch self {
            case .white: return .white
            case .black: return .black
            case .red: return .red
            case .blue: return .blue
            case .yellow: return .yellow
            case .green: return .green
            }
        }
    }
    
    enum TextAlignment: String, Codable {
        case left, center, right
    }
    
    init(text: String = "", positionX: Double = 0.5, positionY: Double = 0.5, fontSize: Double = 40, color: TextColor = .white, alignment: TextAlignment = .center) {
        self.text = text
        self.positionX = positionX
        self.positionY = positionY
        self.fontSize = fontSize
        self.color = color
        self.alignment = alignment
    }
}

// Video trim range
struct TrimRange {
    var startTime: Double
    var endTime: Double
    
    var duration: Double {
        return max(0, endTime - startTime)
    }
    
    var isValid: Bool {
        return startTime >= 0 && endTime > startTime && duration <= 8.0
    }
}

@MainActor
class VideoEditingViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var editedVideoURL: URL?
    @Published var isPosting = false
    @Published var errorMessage: String?
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    
    // Text overlay properties
    @Published var textOverlay: TextOverlay? = nil
    @Published var isEditingText = false
    
    // Video trimming properties
    @Published var trimRange: TrimRange?
    @Published var videoDuration: Double = 0.0
    @Published var isTrimming = false
    
    private let videoService = VideoService()
    private let storageService = StorageService()
    private var originalAsset: AVAsset?
    
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
                originalAsset = asset
                videoDuration = duration.seconds
                
                // Initialize trim range to full video
                trimRange = TrimRange(startTime: 0, endTime: min(videoDuration, 8.0))
                
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
        isExporting = true
        errorMessage = nil
        exportProgress = 0.0
        
        do {
            // Export edited video (with text overlay and trimming)
            let finalVideoURL = try await exportEditedVideo(originalURL: originalURL)
            
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
            
            // Store text overlay info if present
            let editedText = textOverlay?.text.isEmpty == false ? textOverlay?.text : nil
            
            let video = Video(
                id: videoId,
                userId: userId,
                videoURL: videoURL,
                thumbnailURL: thumbnailURL,
                duration: duration,
                parentVideoId: parentVideoId,
                editedText: editedText
            )
            
            try await videoService.uploadVideo(video)
            try await videoService.incrementResponseCount(videoId: parentVideoId)
            
            isPosting = false
            isExporting = false
        } catch {
            isPosting = false
            isExporting = false
            errorMessage = error.localizedDescription
        }
    }
    
    func postVideo(originalURL: URL) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isPosting = true
        isExporting = true
        errorMessage = nil
        exportProgress = 0.0
        
        do {
            // Export edited video (with text overlay and trimming)
            let finalVideoURL = try await exportEditedVideo(originalURL: originalURL)
            
            // Generate thumbnail from final video
            let thumbnail = try await generateThumbnail(from: finalVideoURL)
            
            let videoId = UUID().uuidString
            
            // Upload video
            let videoURL = try await storageService.uploadVideo(
                url: finalVideoURL,
                userId: userId,
                videoId: videoId
            )
            
            // Upload thumbnail
            let thumbnailURL = try await storageService.uploadThumbnail(
                image: thumbnail,
                userId: userId,
                videoId: videoId
            )
            
            // Get video duration
            let asset = AVAsset(url: finalVideoURL)
            let duration = try await asset.load(.duration).seconds
            
            // Store text overlay info if present
            let editedText = textOverlay?.text.isEmpty == false ? textOverlay?.text : nil
            
            // Create video document
            let video = Video(
                id: videoId,
                userId: userId,
                videoURL: videoURL,
                thumbnailURL: thumbnailURL,
                duration: duration,
                editedText: editedText
            )
            
            try await videoService.uploadVideo(video)
            
            isPosting = false
            isExporting = false
        } catch {
            isPosting = false
            isExporting = false
            errorMessage = error.localizedDescription
        }
    }
    
    func exportEditedVideo(originalURL: URL) async throws -> URL {
        let asset: AVAsset
        if let existingAsset = originalAsset {
            asset = existingAsset
        } else {
            asset = AVAsset(url: originalURL)
            originalAsset = asset
        }
        
        // Determine trim range
        let startTime: Double
        let endTime: Double
        
        if let trim = trimRange, trim.isValid && trim.duration > 0.1 {
            startTime = max(0, min(trim.startTime, videoDuration - 0.1))
            endTime = min(trim.endTime, videoDuration)
        } else {
            startTime = 0
            endTime = min(videoDuration, 8.0)
        }
        
        // Ensure minimum duration
        let finalDuration = max(0.1, endTime - startTime)
        
        let timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: finalDuration, preferredTimescale: 600)
        )
        
        // Create composition
        let composition = AVMutableComposition()
        
        // Add video track
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoEditing", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try compositionVideoTrack?.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        
        // Add audio track if available
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compositionAudioTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }
        
        // Calculate correct render size - this is CRITICAL for proper export
        let transform = videoTrack.preferredTransform
        let naturalSize = videoTrack.naturalSize
        
        // Determine if video is portrait based on transform
        // Transform matrix: [a b c d tx ty]
        // a=0, b=1: 90° rotation (portrait)
        // a=0, b=-1: 270° rotation (portrait flipped)
        let isPortrait = abs(transform.a) < 0.1 && abs(transform.b) > 0.9
        let isPortraitFlipped = abs(transform.a) < 0.1 && abs(transform.b) < -0.9
        
        // Calculate the actual display size (what user sees)
        // For portrait videos, swap dimensions
        let displaySize: CGSize
        if isPortrait || isPortraitFlipped {
            displaySize = CGSize(width: naturalSize.height, height: naturalSize.width)
        } else {
            displaySize = naturalSize
        }
        
        // Use displaySize as renderSize so output file has correct dimensions
        // This ensures exported video is portrait (1080x1920) not landscape (1920x1080)
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = displaySize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        // Create instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack!)
        
        // Calculate transform to rotate source (naturalSize) into output (displaySize)
        // Use the preferredTransform's rotation but adjust translation for new renderSize
        if isPortrait {
            // Portrait: 90° clockwise rotation
            // preferredTransform typically: [0 1; -1 0; tx ty]
            // We keep rotation [0 1; -1 0] but recalculate translation
            // After 90° rotation, source (1920x1080) becomes (1080x1920)
            // To position at origin: translate by (1080, 0)
            let rotation = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)
            let translation = CGAffineTransform(translationX: displaySize.width, y: 0)
            layerInstruction.setTransform(rotation.concatenating(translation), at: .zero)
        } else if isPortraitFlipped {
            // Portrait flipped: 270° (-90°) rotation
            // Rotation: [0 -1; 1 0]
            let rotation = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 0)
            let translation = CGAffineTransform(translationX: 0, y: displaySize.height)
            layerInstruction.setTransform(rotation.concatenating(translation), at: .zero)
        } else {
            // Landscape: no transform needed
            layerInstruction.setTransform(CGAffineTransform.identity, at: .zero)
        }
        
        instruction.layerInstructions = [layerInstruction]
        
        videoComposition.instructions = [instruction]
        
            // Add text overlay if present
            if let textOverlay = textOverlay, !textOverlay.text.isEmpty {
                let overlayLayer = CALayer()
                // Overlay layer must match renderSize (displaySize)
                overlayLayer.frame = CGRect(origin: .zero, size: displaySize)
                overlayLayer.isOpaque = false
                
                // Text coordinates are in displaySize (what user sees)
                // Since renderSize = displaySize, coordinates match directly
                let textX = textOverlay.positionX * displaySize.width
                let textY = (1.0 - textOverlay.positionY) * displaySize.height // Flip Y for Core Animation
                
                // Create text layer
                let textLayer = CATextLayer()
                textLayer.string = textOverlay.text
                textLayer.fontSize = textOverlay.fontSize
                textLayer.foregroundColor = textOverlay.color.uiColor.cgColor
                
                // Set alignment
                switch textOverlay.alignment {
                case .left:
                    textLayer.alignmentMode = .left
                case .center:
                    textLayer.alignmentMode = .center
                case .right:
                    textLayer.alignmentMode = .right
                }
                
                textLayer.isWrapped = true
                textLayer.contentsScale = UIScreen.main.scale
                
                // Estimate text size (use displaySize)
                let font = UIFont.systemFont(ofSize: textOverlay.fontSize)
                let attributes: [NSAttributedString.Key: Any] = [.font: font]
                let attributedString = NSAttributedString(string: textOverlay.text, attributes: attributes)
                let textSize = attributedString.boundingRect(
                    with: CGSize(width: displaySize.width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                
                // Set frame based on alignment
                var textFrame: CGRect
                let padding: CGFloat = 20
                switch textOverlay.alignment {
                case .left:
                    textFrame = CGRect(
                        x: max(padding, textX - padding),
                        y: textY - textSize.height / 2,
                        width: min(displaySize.width - textX, textSize.width + padding * 2),
                        height: textSize.height + padding
                    )
                case .center:
                    textFrame = CGRect(
                        x: textX - textSize.width / 2 - padding,
                        y: textY - textSize.height / 2,
                        width: textSize.width + padding * 2,
                        height: textSize.height + padding
                    )
                case .right:
                    textFrame = CGRect(
                        x: textX - textSize.width - padding,
                        y: textY - textSize.height / 2,
                        width: min(textX, textSize.width + padding * 2),
                        height: textSize.height + padding
                    )
                }
                
                // Ensure text stays within bounds (displaySize)
                textFrame = textFrame.intersection(CGRect(origin: .zero, size: displaySize))
                if textFrame.width > 0 && textFrame.height > 0 {
                    textLayer.frame = textFrame
                    overlayLayer.addSublayer(textLayer)
                }
                
                // Use animation tool to add overlay
                // CRITICAL: videoLayer must be added FIRST, then overlayLayer on top
                // Both layers use displaySize which matches renderSize
                let parentLayer = CALayer()
                let videoLayer = CALayer()
                
                // Set up parent layer
                parentLayer.frame = CGRect(origin: .zero, size: displaySize)
                parentLayer.masksToBounds = true
                
                // Set up video layer - this will receive the rendered video frames
                // The video will be transformed by the layer instruction, then composited here
                videoLayer.frame = CGRect(origin: .zero, size: displaySize)
                videoLayer.contentsGravity = .resizeAspectFill
                
                // Set up overlay layer (already set above, but ensure it matches)
                overlayLayer.frame = CGRect(origin: .zero, size: displaySize)
                
                // Add video layer first (bottom), then overlay (top)
                // This ensures video renders behind the text
                parentLayer.addSublayer(videoLayer)
                parentLayer.addSublayer(overlayLayer)
                
                let animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
                videoComposition.animationTool = animationTool
            }
        
        // Export
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("edited_\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "VideoEditing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        
        // Monitor progress
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.exportProgress = Double(exportSession.progress)
            }
        }
        
        await exportSession.export()
        progressTimer.invalidate()
        
        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(domain: "VideoEditing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
        }
        
        return outputURL
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
