//
//  OnboardingViewModel.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import SwiftUI
import FirebaseAuth

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var selectedSchool: School?
    @Published var selectedGrade: Grade?
    @Published var displayName: String = ""
    @Published var bio: String = ""
    @Published var profileImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func proceedToSignIn() {
        navigationPath.append(OnboardingStep.signIn)
    }
    
    func proceedToSchoolSelection() {
        navigationPath.append(OnboardingStep.schoolSelection)
    }
    
    func proceedToGradeSelection() {
        guard selectedSchool != nil else { return }
        navigationPath.append(OnboardingStep.gradeSelection)
    }
    
    func proceedToProfileSetup() {
        guard selectedGrade != nil else { return }
        navigationPath.append(OnboardingStep.profileSetup)
    }
    
    func completeOnboarding(authService: AuthService) async throws {
        guard let firebaseUser = FirebaseAuth.Auth.auth().currentUser,
              let school = selectedSchool,
              let grade = selectedGrade else {
            throw OnboardingError.missingData
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Upload profile picture if provided
            var profilePictureURL: String? = nil
            if let profileImage = profileImage {
                let storageService = StorageService()
                profilePictureURL = try await storageService.uploadProfilePicture(
                    image: profileImage,
                    userId: firebaseUser.uid
                )
            }
            
            // Create user
            let user = User(
                id: firebaseUser.uid,
                email: firebaseUser.email ?? "",
                displayName: displayName.isEmpty ? (firebaseUser.displayName ?? "User") : displayName,
                profilePictureURL: profilePictureURL,
                school: school,
                grade: grade,
                bio: bio.isEmpty ? nil : bio
            )
            
            let userService = UserService()
            try await userService.createUser(user)
            
            // Update auth service
            authService.currentUser = user
            authService.isAuthenticated = true
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

enum OnboardingError: LocalizedError {
    case missingData
    case authServiceNotAvailable
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .missingData:
            return "Please complete all required fields"
        case .authServiceNotAvailable:
            return "Authentication service not available"
        case .notAuthenticated:
            return "Not authenticated"
        }
    }
}
