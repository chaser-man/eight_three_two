//
//  SignInView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var authService: AuthService
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 20) {
                Text("Sign In")
                    .font(.system(size: 32, weight: .semibold))
                
                Text("Please use your washk12.org email")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding()
            }
            
            Button(action: {
                Task {
                    await signInWithGoogle()
                }
            }) {
                HStack {
                    if isSigningIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "globe")
                        Text("Sign in with Google")
                    }
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(isSigningIn)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func signInWithGoogle() async {
        isSigningIn = true
        errorMessage = nil
        
        do {
            try await authService.signInWithGoogle()
            
            // Check if user needs onboarding
            if authService.currentUser == nil {
                // User signed in but needs to complete profile
                viewModel.proceedToSchoolSelection()
            }
            // If user exists, authService will update isAuthenticated automatically
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSigningIn = false
    }
}
