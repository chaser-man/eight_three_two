//
//  WelcomeView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Logo/Name
            VStack(spacing: 20) {
                Text("8")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Welcome to Eight")
                    .font(.system(size: 32, weight: .semibold))
            }
            
            Spacer()
            
            Text("Share your moments in 8 seconds")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                viewModel.proceedToSignIn()
            }) {
                Text("Get Started")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
    }
}
