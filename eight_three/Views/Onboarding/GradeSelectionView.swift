//
//  GradeSelectionView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI

struct GradeSelectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Your Grade")
                .font(.system(size: 28, weight: .semibold))
                .padding(.top, 40)
            
            List {
                ForEach(Grade.allCases, id: \.self) { grade in
                    Button(action: {
                        viewModel.selectedGrade = grade
                        viewModel.proceedToProfileSetup()
                    }) {
                        HStack {
                            Text(grade.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if viewModel.selectedGrade == grade {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
