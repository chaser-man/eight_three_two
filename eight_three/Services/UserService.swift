//
//  UserService.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import FirebaseFirestore
import Combine

class UserService {
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    
    func createUser(_ user: User) async throws {
        let userData: [String: Any] = [
            "id": user.id,
            "email": user.email,
            "displayName": user.displayName,
            "profilePictureURL": user.profilePictureURL as Any,
            "school": user.school.rawValue,
            "grade": user.grade.rawValue,
            "bio": user.bio as Any,
            "createdAt": user.createdAt,
            "followerCount": user.followerCount,
            "followingCount": user.followingCount,
            "videoCount": user.videoCount
        ]
        
        try await db.collection(usersCollection).document(user.id).setData(userData)
    }
    
    func getUser(userId: String) async throws -> User? {
        let document = try await db.collection(usersCollection).document(userId).getDocument()
        
        guard document.exists,
              let data = document.data() else {
            return nil
        }
        
        return try decodeUser(from: data, id: userId)
    }
    
    func updateUser(_ user: User) async throws {
        let userData: [String: Any] = [
            "displayName": user.displayName,
            "profilePictureURL": user.profilePictureURL as Any,
            "bio": user.bio as Any,
            "followerCount": user.followerCount,
            "followingCount": user.followingCount,
            "videoCount": user.videoCount
        ]
        
        try await db.collection(usersCollection).document(user.id).updateData(userData)
    }
    
    func searchUsers(query: String, school: School? = nil, grade: Grade? = nil, excludeUserId: String? = nil) async throws -> [User] {
        var queryRef: Query = db.collection(usersCollection)
        
        if let school = school {
            queryRef = queryRef.whereField("school", isEqualTo: school.rawValue)
        }
        
        if let grade = grade {
            queryRef = queryRef.whereField("grade", isEqualTo: grade.rawValue)
        }
        
        // Limit results for performance (we can paginate later if needed)
        queryRef = queryRef.limit(to: 50)
        
        let snapshot = try await queryRef.getDocuments()
        
        return try snapshot.documents.compactMap { document in
            let userId = document.documentID
            
            // Exclude current user from results
            if let excludeId = excludeUserId, userId == excludeId {
                return nil
            }
            
            let data = document.data()
            let displayName = data["displayName"] as? String ?? ""
            
            // Filter by query string if provided (case-insensitive search)
            if !query.isEmpty && !displayName.localizedCaseInsensitiveContains(query) {
                return nil
            }
            
            return try decodeUser(from: data, id: userId)
        }
    }
    
    func followUser(followerId: String, followingId: String) async throws {
        let followId = "\(followerId)_\(followingId)"
        let followData: [String: Any] = [
            "id": followId,
            "followerId": followerId,
            "followingId": followingId,
            "createdAt": Timestamp()
        ]
        
        try await db.collection("follows").document(followId).setData(followData)
        
        // Update follower counts
        try await incrementFollowerCount(userId: followingId)
        try await incrementFollowingCount(userId: followerId)
    }
    
    func unfollowUser(followerId: String, followingId: String) async throws {
        let followId = "\(followerId)_\(followingId)"
        try await db.collection("follows").document(followId).delete()
        
        // Update follower counts
        try await decrementFollowerCount(userId: followingId)
        try await decrementFollowingCount(userId: followerId)
    }
    
    func isFollowing(followerId: String, followingId: String) async throws -> Bool {
        let followId = "\(followerId)_\(followingId)"
        let document = try await db.collection("follows").document(followId).getDocument()
        return document.exists
    }
    
    func getFollowing(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("follows")
            .whereField("followerId", isEqualTo: userId)
            .getDocuments()
        
        return snapshot.documents.map { $0.data()["followingId"] as? String ?? "" }
    }
    
    private func incrementFollowerCount(userId: String) async throws {
        let userRef = db.collection(usersCollection).document(userId)
        try await userRef.updateData([
            "followerCount": FieldValue.increment(Int64(1))
        ])
    }
    
    private func decrementFollowerCount(userId: String) async throws {
        let userRef = db.collection(usersCollection).document(userId)
        try await userRef.updateData([
            "followerCount": FieldValue.increment(Int64(-1))
        ])
    }
    
    private func incrementFollowingCount(userId: String) async throws {
        let userRef = db.collection(usersCollection).document(userId)
        try await userRef.updateData([
            "followingCount": FieldValue.increment(Int64(1))
        ])
    }
    
    private func decrementFollowingCount(userId: String) async throws {
        let userRef = db.collection(usersCollection).document(userId)
        try await userRef.updateData([
            "followingCount": FieldValue.increment(Int64(-1))
        ])
    }
    
    private func decodeUser(from data: [String: Any], id: String) throws -> User {
        guard let email = data["email"] as? String,
              let displayName = data["displayName"] as? String,
              let schoolString = data["school"] as? String,
              let school = School(rawValue: schoolString),
              let gradeString = data["grade"] as? String,
              let grade = Grade(rawValue: gradeString),
              let createdAt = data["createdAt"] as? Timestamp else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "Invalid user data"
            ))
        }
        
        return User(
            id: id,
            email: email,
            displayName: displayName,
            profilePictureURL: data["profilePictureURL"] as? String,
            school: school,
            grade: grade,
            bio: data["bio"] as? String,
            createdAt: createdAt,
            followerCount: data["followerCount"] as? Int ?? 0,
            followingCount: data["followingCount"] as? Int ?? 0,
            videoCount: data["videoCount"] as? Int ?? 0
        )
    }
}
