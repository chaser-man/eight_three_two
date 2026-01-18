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
    @Published var errorMessage: String?
    
    private let userService = UserService()
    var authService: AuthService?
    
    func searchUsers(query: String, school: School? = nil, grade: Grade? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let currentUserId = Auth.auth().currentUser?.uid
            searchResults = try await userService.searchUsers(
                query: query,
                school: school,
                grade: grade,
                excludeUserId: currentUserId
            )
            
            // Check following status for each user
            if let currentUserId = currentUserId {
                for user in searchResults {
                    await checkFollowingStatus(userId: user.id)
                }
            }
        } catch {
            errorMessage = "Failed to search users: \(error.localizedDescription)"
            print("Error searching users: \(error)")
            searchResults = []
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
            
            // Update the user in searchResults to reflect new follower count
            if let index = searchResults.firstIndex(where: { $0.id == userId }) {
                var updatedUser = searchResults[index]
                if isCurrentlyFollowing {
                    updatedUser.followerCount = max(0, updatedUser.followerCount - 1)
                } else {
                    updatedUser.followerCount += 1
                }
                searchResults[index] = updatedUser
            }
            
            // Refresh current user's data to update following count
            if let authService = authService,
               let updatedCurrentUser = try await userService.getUser(userId: currentUserId) {
                authService.currentUser = updatedCurrentUser
            }
        } catch {
            errorMessage = "Failed to update follow status: \(error.localizedDescription)"
            print("Error toggling follow: \(error)")
        }
    }
}
