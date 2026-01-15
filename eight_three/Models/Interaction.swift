//
//  Interaction.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import FirebaseFirestore

struct Interaction: Codable, Identifiable {
    let id: String
    let userId: String
    let videoId: String
    let type: InteractionType
    let createdAt: Timestamp
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case videoId
        case type
        case createdAt
    }
    
    init(id: String, userId: String, videoId: String, type: InteractionType, createdAt: Timestamp = Timestamp()) {
        self.id = id
        self.userId = userId
        self.videoId = videoId
        self.type = type
        self.createdAt = createdAt
    }
}

enum InteractionType: String, Codable {
    case like
    case dislike
}

struct Follow: Codable, Identifiable {
    let id: String
    let followerId: String
    let followingId: String
    let createdAt: Timestamp
    
    enum CodingKeys: String, CodingKey {
        case id
        case followerId
        case followingId
        case createdAt
    }
    
    init(id: String, followerId: String, followingId: String, createdAt: Timestamp = Timestamp()) {
        self.id = id
        self.followerId = followerId
        self.followingId = followingId
        self.createdAt = createdAt
    }
}
