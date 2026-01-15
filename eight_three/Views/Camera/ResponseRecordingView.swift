//
//  ResponseRecordingView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI
import AVKit

struct ResponseRecordingView: View {
    let parentVideoId: String
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var viewModel = CameraViewModel()
    @State private var zoomValue: CGFloat = 1.0
    @State private var showingEditing = false
    @State private var recordedVideoURL: URL?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Camera Preview
            if let previewLayer = cameraManager.previewLayer {
                CameraPreviewLayer(layer: previewLayer)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }
            
            VStack {
                Spacer()
                
                // Countdown Timer
                if cameraManager.isRecording {
                    VStack {
                        Text("\(Int(cameraManager.maxRecordingDuration - cameraManager.recordedDuration))")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 5)
                        
                        ProgressView(value: cameraManager.recordedDuration, total: cameraManager.maxRecordingDuration)
                            .progressViewStyle(LinearProgressViewStyle(tint: .red))
                            .frame(width: 200)
                    }
                    .padding(.top, 50)
                }
                
                Spacer()
                
                // Bottom Controls
                HStack {
                    Spacer()
                    
                    // Record Button
                    Button(action: {
                        if cameraManager.isRecording {
                            cameraManager.stopRecording()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if let url = cameraManager.getRecordedVideoURL() {
                                    recordedVideoURL = url
                                    showingEditing = true
                                }
                            }
                        } else {
                            do {
                                try cameraManager.startRecording()
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(cameraManager.isRecording ? Color.red : Color.white)
                                .frame(width: 70, height: 70)
                            
                            if !cameraManager.isRecording {
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 60, height: 60)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                    
                    Spacer()
                }
                
                // Zoom Control
                VStack {
                    Slider(value: $zoomValue, in: 1.0...cameraManager.maxZoomFactor, onEditingChanged: { editing in
                        if !editing {
                            cameraManager.setZoom(factor: zoomValue)
                        }
                    })
                    .frame(width: 200)
                    .accentColor(.white)
                    
                    Text("Zoom")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showingEditing) {
            if let videoURL = recordedVideoURL {
                ResponseEditingView(
                    videoURL: videoURL,
                    parentVideoId: parentVideoId,
                    onPostComplete: {
                        // Dismiss the sheet first, then dismiss this fullScreenCover
                        showingEditing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    }
                )
            }
        }
    }
}

struct ResponseEditingView: View {
    let videoURL: URL
    let parentVideoId: String
    let onPostComplete: () -> Void
    @StateObject private var viewModel = VideoEditingViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Video Preview
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .frame(height: 400)
                        .onAppear {
                            player.play()
                        }
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 400)
                        .overlay(ProgressView())
                }
                
                // Editing Controls
                VStack(spacing: 15) {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        Task {
                            await postResponse()
                        }
                    }) {
                        if viewModel.isPosting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Post Response")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isPosting ? Color.gray : Color.blue)
                    .cornerRadius(12)
                    .disabled(viewModel.isPosting)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Edit Response")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadVideo(url: videoURL)
            }
        }
    }
    
    private func postResponse() async {
        await viewModel.postResponse(originalURL: videoURL, parentVideoId: parentVideoId)
        
        // Only dismiss and call completion if posting was successful
        if !viewModel.isPosting && viewModel.errorMessage == nil {
            dismiss()
            // Call the completion handler to dismiss the parent fullScreenCover
            onPostComplete()
        }
    }
}
