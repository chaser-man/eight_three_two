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
    
    func updateProfilePicture(image: UIImage) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        do {
            let profilePictureURL = try await storageService.uploadProfilePicture(
                image: image,
                userId: userId
            )
            
            // Update user in Firestore
            if var user = try await userService.getUser(userId: userId) {
                user.profilePictureURL = profilePictureURL
                try await userService.updateUser(user)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
