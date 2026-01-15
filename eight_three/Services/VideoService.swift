//
//  VideoService.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import FirebaseFirestore
import Combine

class VideoService {
    private let db = Firestore.firestore()
    private let videosCollection = "videos"
    private let pageSize = 20
    
    func uploadVideo(_ video: Video) async throws {
        let videoData: [String: Any] = [
            "id": video.id,
            "userId": video.userId,
            "videoURL": video.videoURL,
            "thumbnailURL": video.thumbnailURL,
            "duration": video.duration,
            "caption": video.caption as Any,
            "createdAt": video.createdAt,
            "likeCount": video.likeCount,
            "dislikeCount": video.dislikeCount,
            "responseCount": video.responseCount,
            "parentVideoId": video.parentVideoId as Any,
            "editedText": video.editedText as Any
        ]
        
        try await db.collection(videosCollection).document(video.id).setData(videoData)
        
        // Update user's video count
        try await incrementUserVideoCount(userId: video.userId)
    }
    
    func getAllVideos(lastDocument: DocumentSnapshot? = nil) async throws -> (videos: [Video], lastDocument: DocumentSnapshot?) {
        print("🔍 Querying videos collection...")
        
        // Get ALL videos - filter out responses in code since Firestore queries are tricky with null/optional fields
        var query: Query = db.collection(videosCollection)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize * 2) // Get more to account for filtering
        
        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        let snapshot = try await query.getDocuments()
        print("📊 Found \(snapshot.documents.count) documents")
        
        // Filter to only main videos (not responses) and decode
        let videos = try snapshot.documents.compactMap { document -> Video? in
            let data = document.data()
            
            // Skip if this is a response (has parentVideoId and it's not null)
            if let parentVideoId = data["parentVideoId"] as? String, !parentVideoId.isEmpty {
                return nil
            }
            
            do {
                return try decodeVideo(from: data, id: document.documentID)
            } catch {
                print("⚠️ Error decoding video \(document.documentID): \(error)")
                return nil
            }
        }
        
        // Limit to pageSize after filtering
        let limitedVideos = Array(videos.prefix(pageSize))
        
        print("✅ Successfully decoded \(limitedVideos.count) main videos (filtered from \(snapshot.documents.count) total)")
        return (limitedVideos, snapshot.documents.last)
    }
    
    func getFeedVideos(followingUserIds: [String], lastDocument: DocumentSnapshot? = nil) async throws -> (videos: [Video], lastDocument: DocumentSnapshot?) {
        // Firestore 'in' query has a limit of 10 items
        // If we have more than 10 users, we need to split the query
        let maxInQuerySize = 10
        var allVideos: [Video] = []
        
        // Split into chunks of 10 if needed
        var chunks: [[String]] = []
        for i in stride(from: 0, to: followingUserIds.count, by: maxInQuerySize) {
            let endIndex = min(i + maxInQuerySize, followingUserIds.count)
            chunks.append(Array(followingUserIds[i..<endIndex]))
        }
        
        // Query each chunk
        for chunk in chunks {
            var query: Query = db.collection(videosCollection)
                .whereField("userId", in: chunk)
                .whereField("parentVideoId", isEqualTo: NSNull())
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize * 2) // Get more to account for merging
            
            let snapshot = try await query.getDocuments()
            let videos = try snapshot.documents.compactMap { document -> Video? in
                try decodeVideo(from: document.data(), id: document.documentID)
            }
            
            allVideos.append(contentsOf: videos)
        }
        
        // Sort all videos by createdAt descending and limit to pageSize
        allVideos.sort { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
        let limitedVideos = Array(allVideos.prefix(pageSize))
        
        // For pagination, we'd need to track the last document differently
        // For now, return nil for lastDocument when using chunked queries
        return (limitedVideos, nil)
    }
    
    func getUserVideos(userId: String) async throws -> [Video] {
        let snapshot = try await db.collection(videosCollection)
            .whereField("userId", isEqualTo: userId)
            .whereField("parentVideoId", isEqualTo: NSNull())
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try decodeVideo(from: document.data(), id: document.documentID)
        }
    }
    
    func getVideoResponses(videoId: String) async throws -> [Video] {
        let snapshot = try await db.collection(videosCollection)
            .whereField("parentVideoId", isEqualTo: videoId)
            .getDocuments()
        
        var responses = try snapshot.documents.compactMap { document -> Video? in
            try decodeVideo(from: document.data(), id: document.documentID)
        }
        
        // Sort by likes (descending), then by recency (descending)
        responses.sort { first, second in
            if first.likeCount != second.likeCount {
                return first.likeCount > second.likeCount
            }
            return first.createdAt.dateValue() > second.createdAt.dateValue()
        }
        
        return responses
    }
    
    func getVideo(videoId: String) async throws -> Video? {
        let document = try await db.collection(videosCollection).document(videoId).getDocument()
        
        guard document.exists,
              let data = document.data() else {
            return nil
        }
        
        return try decodeVideo(from: data, id: videoId)
    }
    
    func deleteVideo(videoId: String, userId: String) async throws {
        try await db.collection(videosCollection).document(videoId).delete()
        try await decrementUserVideoCount(userId: userId)
    }
    
    func incrementResponseCount(videoId: String) async throws {
        try await db.collection(videosCollection).document(videoId).updateData([
            "responseCount": FieldValue.increment(Int64(1))
        ])
    }
    
    private func incrementUserVideoCount(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "videoCount": FieldValue.increment(Int64(1))
        ])
    }
    
    private func decrementUserVideoCount(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "videoCount": FieldValue.increment(Int64(-1))
        ])
    }
    
    private func decodeVideo(from data: [String: Any], id: String) throws -> Video {
        guard let userId = data["userId"] as? String,
              let videoURL = data["videoURL"] as? String,
              let thumbnailURL = data["thumbnailURL"] as? String,
              let duration = data["duration"] as? Double,
              let createdAt = data["createdAt"] as? Timestamp else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "Invalid video data"
            ))
        }
        
        return Video(
            id: id,
            userId: userId,
            videoURL: videoURL,
            thumbnailURL: thumbnailURL,
            duration: duration,
            caption: data["caption"] as? String,
            createdAt: createdAt,
            likeCount: data["likeCount"] as? Int ?? 0,
            dislikeCount: data["dislikeCount"] as? Int ?? 0,
            responseCount: data["responseCount"] as? Int ?? 0,
            parentVideoId: data["parentVideoId"] as? String,
            editedText: data["editedText"] as? String
        )
    }
}
