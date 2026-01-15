//
//  SearchViewModel.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import SwiftUI
import FirebaseAuth

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [User] = []
    @Published var followingStatus: [String: Bool] = [:]
    @Published var isLoading = false
    
    private let userService = UserService()
    
    func searchUsers(query: String, school: School? = nil, grade: Grade? = nil) async {
        isLoading = true
        
        do {
            searchResults = try await userService.searchUsers(
                query: query,
                school: school,
                grade: grade
            )
            
            // Check following status for each user
            if let currentUserId = Auth.auth().currentUser?.uid {
                for user in searchResults {
                    await checkFollowingStatus(userId: user.id)
                }
            }
        } catch {
            print("Error searching users: \(error)")
        }
        
        isLoading = false
    }
    
    func checkFollowingStatus(userId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let isFollowing = try await userService.isFollowing(
                followerId: currentUserId,
                followingId: userId
            )
            followingStatus[userId] = isFollowing
        } catch {
            print("Error checking follow status: \(error)")
        }
    }
    
    func toggleFollow(userId: String, isCurrentlyFollowing: Bool) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            if isCurrentlyFollowing {
                try await userService.unfollowUser(
                    followerId: currentUserId,
                    followingId: userId
                )
            } else {
                try await userService.followUser(
                    followerId: currentUserId,
                    followingId: userId
                )
            }
            
            followingStatus[userId] = !isCurrentlyFollowing
        } catch {
            print("Error toggling follow: \(error)")
        }
    }
}
