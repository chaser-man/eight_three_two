//
//  Video.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import FirebaseFirestore

struct Video: Codable, Identifiable {
    let id: String
    let userId: String
    let videoURL: String
    let thumbnailURL: String
    let duration: Double // max 8.0 seconds
    var caption: String?
    let createdAt: Timestamp
    var likeCount: Int
    var dislikeCount: Int
    var responseCount: Int
    let parentVideoId: String? // nil for original videos, set for responses
    var editedText: String? // Text overlay added during editing
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case videoURL
        case thumbnailURL
        case duration
        case caption
        case createdAt
        case likeCount
        case dislikeCount
        case responseCount
        case parentVideoId
        case editedText
    }
    
    init(id: String, userId: String, videoURL: String, thumbnailURL: String, duration: Double, caption: String? = nil, createdAt: Timestamp = Timestamp(), likeCount: Int = 0, dislikeCount: Int = 0, responseCount: Int = 0, parentVideoId: String? = nil, editedText: String? = nil) {
        self.id = id
        self.userId = userId
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.caption = caption
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.dislikeCount = dislikeCount
        self.responseCount = responseCount
        self.parentVideoId = parentVideoId
        self.editedText = editedText
    }
}
