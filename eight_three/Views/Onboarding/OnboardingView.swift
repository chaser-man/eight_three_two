//
//  OnboardingView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            WelcomeView()
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .signIn:
                        SignInView()
                    case .schoolSelection:
                        SchoolSelectionView()
                    case .gradeSelection:
                        GradeSelectionView()
                    case .profileSetup:
                        ProfileSetupView()
                    }
                }
        }
        .environmentObject(viewModel)
        .environmentObject(authService)
    }
}

enum OnboardingStep: Hashable {
    case signIn
    case schoolSelection
    case gradeSelection
    case profileSetup
}
