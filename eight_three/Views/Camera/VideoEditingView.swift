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
                    // Video Preview
                    if let player = viewModel.player {
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
