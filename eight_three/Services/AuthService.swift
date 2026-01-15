//
//  AuthService.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true // Start as true to prevent flash of onboarding
    @Published var errorMessage: String?
    
    private let userService = UserService()
    private let allowedDomain = "washk12.org"
    
    init() {
        checkAuthState()
    }
    
    func checkAuthState() {
        isLoading = true
        if let firebaseUser = Auth.auth().currentUser {
            Task {
                await loadUserData(userId: firebaseUser.uid)
                isLoading = false
            }
        } else {
            // No authenticated user, show onboarding
            isLoading = false
        }
    }
    
    func signInWithGoogle() async throws {
        isLoading = true
        errorMessage = nil
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configurationError
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = await windowScene.windows.first,
              let rootViewController = await window.rootViewController else {
            throw AuthError.presentationError
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.tokenError
        }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
        
        // Validate email domain
        let email = result.user.profile?.email ?? ""
        guard email.hasSuffix("@\(allowedDomain)") else {
            throw AuthError.invalidEmailDomain
        }
        
        let authResult = try await Auth.auth().signIn(with: credential)
        
        // Check if user exists, if not they need to complete onboarding
        await loadUserData(userId: authResult.user.uid)
        
        isLoading = false
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
        isAuthenticated = false
    }
    
    private func loadUserData(userId: String) async {
        do {
            if let user = try await userService.getUser(userId: userId) {
                currentUser = user
                isAuthenticated = true
            } else {
                // User doesn't exist yet, needs onboarding
                isAuthenticated = false
            }
        } catch {
            print("Error loading user data: \(error)")
            isAuthenticated = false
        }
        isLoading = false
    }
    
    func validateEmailDomain(_ email: String) -> Bool {
        return email.hasSuffix("@\(allowedDomain)")
    }
}

enum AuthError: LocalizedError {
    case configurationError
    case presentationError
    case tokenError
    case invalidEmailDomain
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .configurationError:
            return "Authentication configuration error"
        case .presentationError:
            return "Unable to present sign-in"
        case .tokenError:
            return "Failed to get authentication token"
        case .invalidEmailDomain:
            return "Please use your washk12.org email"
        case .userNotFound:
            return "User not found"
        }
    }
}
