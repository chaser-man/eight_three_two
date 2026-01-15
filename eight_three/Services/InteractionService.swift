//
//  InteractionService.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import FirebaseFirestore

class InteractionService {
    private let db = Firestore.firestore()
    private let interactionsCollection = "interactions"
    
    func likeVideo(userId: String, videoId: String) async throws {
        // Check if user already disliked
        if let existingInteraction = try await getInteraction(userId: userId, videoId: videoId) {
            if existingInteraction.type == .dislike {
                // Remove dislike first
                try await undislikeVideo(userId: userId, videoId: videoId)
            } else if existingInteraction.type == .like {
                // Already liked, remove like
                try await unlikeVideo(userId: userId, videoId: videoId)
                return
            }
        }
        
        let interactionId = "\(userId)_\(videoId)_like"
        let interactionData: [String: Any] = [
            "id": interactionId,
            "userId": userId,
            "videoId": videoId,
            "type": InteractionType.like.rawValue,
            "createdAt": Timestamp()
        ]
        
        try await db.collection(interactionsCollection).document(interactionId).setData(interactionData)
        try await updateVideoLikeCount(videoId: videoId, increment: 1)
    }
    
    func unlikeVideo(userId: String, videoId: String) async throws {
        let interactionId = "\(userId)_\(videoId)_like"
        try await db.collection(interactionsCollection).document(interactionId).delete()
        try await updateVideoLikeCount(videoId: videoId, increment: -1)
    }
    
    func dislikeVideo(userId: String, videoId: String) async throws {
        // Check if user already liked
        if let existingInteraction = try await getInteraction(userId: userId, videoId: videoId) {
            if existingInteraction.type == .like {
                // Remove like first
                try await unlikeVideo(userId: userId, videoId: videoId)
            } else if existingInteraction.type == .dislike {
                // Already disliked, remove dislike
                try await undislikeVideo(userId: userId, videoId: videoId)
                return
            }
        }
        
        let interactionId = "\(userId)_\(videoId)_dislike"
        let interactionData: [String: Any] = [
            "id": interactionId,
            "userId": userId,
            "videoId": videoId,
            "type": InteractionType.dislike.rawValue,
            "createdAt": Timestamp()
        ]
        
        try await db.collection(interactionsCollection).document(interactionId).setData(interactionData)
        try await updateVideoDislikeCount(videoId: videoId, increment: 1)
    }
    
    func undislikeVideo(userId: String, videoId: String) async throws {
        let interactionId = "\(userId)_\(videoId)_dislike"
        try await db.collection(interactionsCollection).document(interactionId).delete()
        try await updateVideoDislikeCount(videoId: videoId, increment: -1)
    }
    
    func getInteraction(userId: String, videoId: String) async throws -> Interaction? {
        // Check for like
        let likeId = "\(userId)_\(videoId)_like"
        let likeDoc = try await db.collection(interactionsCollection).document(likeId).getDocument()
        
        if likeDoc.exists, let data = likeDoc.data() {
            return try decodeInteraction(from: data, id: likeId)
        }
        
        // Check for dislike
        let dislikeId = "\(userId)_\(videoId)_dislike"
        let dislikeDoc = try await db.collection(interactionsCollection).document(dislikeId).getDocument()
        
        if dislikeDoc.exists, let data = dislikeDoc.data() {
            return try decodeInteraction(from: data, id: dislikeId)
        }
        
        return nil
    }
    
    private func updateVideoLikeCount(videoId: String, increment: Int) async throws {
        let videoRef = db.collection("videos").document(videoId)
        
        do {
            // Try to update with increment - this works even if likeCount field doesn't exist
            print("📝 Updating like count for video \(videoId): incrementing by \(increment)")
            try await videoRef.updateData([
                "likeCount": FieldValue.increment(Int64(increment))
            ])
            print("✅ Successfully updated like count for video \(videoId)")
        } catch {
            // If updateData fails (document doesn't exist), try to get current count and set it
            print("⚠️ Error updating like count with increment for video \(videoId): \(error.localizedDescription)")
            
            // Try to get the current document to see if it exists
            let document = try await videoRef.getDocument()
            
            if document.exists, let data = document.data() {
                // Document exists but updateData failed for some reason
                // Get current count and set new value
                let currentCount = (data["likeCount"] as? Int) ?? 0
                let newCount = max(0, currentCount + increment)
                print("📝 Retrying with explicit count: \(currentCount) -> \(newCount)")
                try await videoRef.updateData([
                    "likeCount": newCount
                ])
                print("✅ Successfully updated like count (fallback method) for video \(videoId)")
            } else {
                // Document doesn't exist - this shouldn't happen for videos
                // But set initial count if increment is positive
                if increment > 0 {
                    print("⚠️ Video document \(videoId) doesn't exist, creating with likeCount: \(increment)")
                    try await videoRef.setData([
                        "likeCount": increment
                    ], merge: true)
                } else {
                    throw error // Re-throw if we can't handle it
                }
            }
        }
    }
    
    private func updateVideoDislikeCount(videoId: String, increment: Int) async throws {
        try await db.collection("videos").document(videoId).updateData([
            "dislikeCount": FieldValue.increment(Int64(increment))
        ])
    }
    
    private func decodeInteraction(from data: [String: Any], id: String) throws -> Interaction {
        guard let userId = data["userId"] as? String,
              let videoId = data["videoId"] as? String,
              let typeString = data["type"] as? String,
              let type = InteractionType(rawValue: typeString),
              let createdAt = data["createdAt"] as? Timestamp else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "Invalid interaction data"
            ))
        }
        
        return Interaction(
            id: id,
            userId: userId,
            videoId: videoId,
            type: type,
            createdAt: createdAt
        )
    }
}
