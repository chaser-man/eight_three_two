//
//  VideoEditingView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoEditingView: View {
    let videoURL: URL
    @StateObject private var viewModel = VideoEditingViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Video Preview with Text Overlay
                    if let player = viewModel.player {
                        ZStack {
                            VideoPlayer(player: player)
                                .frame(height: 400)
                                .onAppear {
                                    player.play()
                                    // Loop the video
                                    NotificationCenter.default.addObserver(
                                        forName: .AVPlayerItemDidPlayToEndTime,
                                        object: player.currentItem,
                                        queue: .main
                                    ) { _ in
                                        player.seek(to: .zero)
                                        player.play()
                                    }
                                }
                            
                            // Real-time text overlay preview
                            if !viewModel.overlayText.isEmpty {
                                Text(viewModel.overlayText)
                                    .font(.system(size: viewModel.fontSize, weight: .semibold))
                                    .foregroundColor(viewModel.textColor)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 20)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                        .frame(height: 400)
                        .clipped()
                    } else if isLoading {
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 400)
                            .overlay(
                                VStack {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Loading video...")
                                        .foregroundColor(.white)
                                        .padding(.top, 10)
                                }
                            )
                    } else {
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 400)
                            .overlay(
                                VStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                    Text("Failed to load video")
                                        .foregroundColor(.white)
                                        .padding(.top, 10)
                                    if let error = viewModel.errorMessage {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .padding(.top, 5)
                                    }
                                }
                            )
                    }
                
                // Editing Controls
                VStack(spacing: 15) {
                    // Text Overlay
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add Text Overlay")
                            .font(.system(size: 16, weight: .medium))
                        TextField("Enter text...", text: $viewModel.overlayText)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                    
                    // Font Size and Color Controls
                    VStack(spacing: 15) {
                        // Font Size Control
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Font Size")
                                .font(.system(size: 16, weight: .medium))
                            HStack {
                                Text("\(Int(viewModel.fontSize))")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 50, alignment: .leading)
                                Slider(value: $viewModel.fontSize, in: viewModel.minFontSize...viewModel.maxFontSize)
                            }
                        }
                        
                        // Text Color Control
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Text Color")
                                .font(.system(size: 16, weight: .medium))
                            HStack(spacing: 12) {
                                // Color picker buttons
                                ColorButton(color: .white, isSelected: viewModel.textColor == .white, action: { viewModel.textColor = .white })
                                ColorButton(color: .black, isSelected: viewModel.textColor == .black, action: { viewModel.textColor = .black })
                                ColorButton(color: .red, isSelected: viewModel.textColor == .red, action: { viewModel.textColor = .red })
                                ColorButton(color: .blue, isSelected: viewModel.textColor == .blue, action: { viewModel.textColor = .blue })
                                ColorButton(color: .green, isSelected: viewModel.textColor == .green, action: { viewModel.textColor = .green })
                                ColorButton(color: .yellow, isSelected: viewModel.textColor == .yellow, action: { viewModel.textColor = .yellow })
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Discard")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.postVideo(originalURL: videoURL)
                                await MainActor.run {
                                    // Post notification to refresh feed
                                    NotificationCenter.default.post(name: NSNotification.Name("VideoPosted"), object: nil)
                                    dismiss()
                                }
                            }
                        }) {
                            if viewModel.isPosting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Post")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isPosting ? Color.gray : Color.blue)
                        .cornerRadius(12)
                        .disabled(viewModel.isPosting)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                }
            }
            .navigationTitle("Edit Video")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                isLoading = true
                await viewModel.loadVideo(url: videoURL)
                isLoading = false
            }
            .onAppear {
                // Ensure video loads when view appears if not already loaded
                if viewModel.player == nil && !isLoading {
                    isLoading = true
                    Task {
                        await viewModel.loadVideo(url: videoURL)
                        isLoading = false
                    }
                }
            }
        }
    }
}

// Color picker button component
struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                )
        }
    }
}
