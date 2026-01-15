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
            if authService.isAuthenticated {
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
