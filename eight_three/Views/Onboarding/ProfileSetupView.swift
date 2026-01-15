//
//  ProfileSetupView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var authService: AuthService
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingImagePicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Complete Your Profile")
                    .font(.system(size: 28, weight: .semibold))
                    .padding(.top, 40)
                
                // Profile Picture
                VStack(spacing: 15) {
                    if let profileImage = viewModel.profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Text("Add Profile Picture")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                }
                .sheet(isPresented: $showingImagePicker) {
                    ImagePicker(image: $viewModel.profileImage)
                }
                
                // Display Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.system(size: 16, weight: .medium))
                    TextField("Enter your name", text: $viewModel.displayName)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                // Bio
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bio (Optional)")
                        .font(.system(size: 16, weight: .medium))
                    TextField("Tell us about yourself", text: $viewModel.bio, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                .padding(.horizontal)
                
                // Complete Button
                Button(action: {
                    Task {
                        do {
                            try await viewModel.completeOnboarding(authService: authService)
                        } catch {
                            // Error handling is done in viewModel
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Complete Setup")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.displayName.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)
                .disabled(viewModel.isLoading || viewModel.displayName.isEmpty)
                .padding(.horizontal)
                .padding(.top, 20)
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
