//
//  SchoolSelectionView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI

struct SchoolSelectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Your School")
                .font(.system(size: 28, weight: .semibold))
                .padding(.top, 40)
            
            List {
                ForEach(School.allCases, id: \.self) { school in
                    Button(action: {
                        viewModel.selectedSchool = school
                        viewModel.proceedToGradeSelection()
                    }) {
                        HStack {
                            Text(school.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if viewModel.selectedSchool == school {
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
