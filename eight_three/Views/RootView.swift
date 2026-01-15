//
//  RootView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if authService.isLoading {
                // Show loading screen while checking auth state to prevent flash
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else if authService.isAuthenticated {
                if authService.currentUser != nil {
                    MainTabView()
                } else {
                    ProgressView("Loading...")
                }
            } else {
                OnboardingView()
            }
        }
    }
}
