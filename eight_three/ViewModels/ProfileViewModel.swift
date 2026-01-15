//
//  ProfileViewModel.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import SwiftUI
import FirebaseAuth

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var userVideos: [Video] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let videoService = VideoService()
    private let storageService = StorageService()
    private let userService = UserService()
    
    func loadUserVideos(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            userVideos = try await videoService.getUserVideos(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func updateProfilePicture(image: UIImage, authService: AuthService) async {
        guard let userId = Auth.auth().currentUser?.uid else { 
            errorMessage = "User not authenticated"
            return 
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("📤 Uploading profile picture for user \(userId)...")
            let profilePictureURL = try await storageService.uploadProfilePicture(
                image: image,
                userId: userId
            )
            print("✅ Profile picture uploaded: \(profilePictureURL)")
            
            // Update user in Firestore
            if var user = try await userService.getUser(userId: userId) {
                user.profilePictureURL = profilePictureURL
                try await userService.updateUser(user)
                print("✅ User updated in Firestore with new profile picture URL")
                
                // Update authService.currentUser to trigger UI refresh
                authService.currentUser = user
                print("✅ AuthService currentUser updated - UI should refresh")
            } else {
                errorMessage = "User not found in database"
                print("❌ User not found in Firestore")
            }
        } catch {
            // Provide more helpful error messages for Firebase Storage permission errors
            let errorDescription: String
            let errorString = error.localizedDescription.lowercased()
            
            if errorString.contains("permission") || 
               errorString.contains("access") ||
               errorString.contains("unauthorized") {
                errorDescription = "Storage permission error. Please update Firebase Storage security rules. See FIREBASE_STORAGE_RULES_FIX.md in the project for instructions."
            } else {
                errorDescription = error.localizedDescription
            }
            
            errorMessage = errorDescription
            print("❌ Error updating profile picture: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}
