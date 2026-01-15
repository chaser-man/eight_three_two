//
//  CameraView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var viewModel = CameraViewModel()
    @State private var zoomValue: CGFloat = 1.0
    @State private var showingEditing = false
    @State private var recordedVideoURL: URL?
    
    init() {
        // Initialize zoom to 1.0
    }
    
    var body: some View {
        ZStack {
            // Camera Preview
            if let previewLayer = cameraManager.previewLayer {
                CameraPreviewLayer(layer: previewLayer)
                    .ignoresSafeArea()
                    .onAppear {
                        // Ensure preview layer frame is set when view appears
                        DispatchQueue.main.async {
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first {
                                previewLayer.frame = window.bounds
                            }
                        }
                    }
            } else {
                Color.black
                    .ignoresSafeArea()
            }
            
            VStack {
                // Countdown Timer at Top
                if cameraManager.isRecording {
                    VStack(spacing: 8) {
                        Text("\(Int(cameraManager.maxRecordingDuration - cameraManager.recordedDuration))")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 5)
                        
                        ProgressView(value: cameraManager.recordedDuration, total: cameraManager.maxRecordingDuration)
                            .progressViewStyle(LinearProgressViewStyle(tint: .red))
                            .frame(width: 200)
                    }
                    .padding(.top, 60)
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
                
                // Bottom Controls
                HStack {
                    Spacer()
                    
                    // Record Button
                    Button(action: {
                        if cameraManager.isRecording {
                            cameraManager.stopRecording()
                            // The callback will handle navigation when recording finishes
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
                                if !cameraManager.isSessionReady {
                                    // Show loading indicator while warming up
                                    ProgressView()
                                        .tint(.gray)
                                } else {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 60, height: 60)
                                }
                            }
                        }
                    }
                    .disabled(!cameraManager.isSessionReady)
                    .opacity(cameraManager.isSessionReady ? 1.0 : 0.6)
                    .padding(.bottom, 30)
                    
                    Spacer()
                }
                
                // Zoom Control
                VStack {
                    Slider(value: $zoomValue, in: cameraManager.minZoomFactor...cameraManager.maxZoomFactor)
                        .frame(width: 200)
                        .accentColor(.white)
                        .onChange(of: zoomValue) { newValue in
                            // Update zoom smoothly in real-time as user drags
                            cameraManager.setZoom(factor: newValue)
                        }
                    
                    Text("Zoom \(String(format: "%.1f", zoomValue))x")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 20)
                .onAppear {
                    zoomValue = 1.0
                }
            }
        }
        .onAppear {
            // Set up callback for when recording finishes (including auto-stop at 8 seconds)
            cameraManager.onRecordingFinished = { [self] url in
                // Verify URL is valid before showing editing screen
                guard FileManager.default.fileExists(atPath: url.path) else {
                    print("Error: Video URL provided but file doesn't exist: \(url.path)")
                    return
                }
                recordedVideoURL = url
                showingEditing = true
            }
            
            // Start session and update preview layer frame
            cameraManager.startSession()
            // Give the session a moment to start, then update preview frame
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let previewLayer = cameraManager.previewLayer {
                    // Force update the preview layer frame
                    previewLayer.frame = UIScreen.main.bounds
                }
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .fullScreenCover(isPresented: $showingEditing) {
            Group {
                if let videoURL = recordedVideoURL {
                    VideoEditingView(videoURL: videoURL)
                } else {
                    // Fallback if URL is nil
                    VStack {
                        Text("Error loading video")
                            .foregroundColor(.red)
                        Button("Close") {
                            showingEditing = false
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

struct CameraPreviewLayer: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer = layer
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer = layer
    }
}

class PreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            // Remove old layer
            if let oldLayer = oldValue {
                oldLayer.removeFromSuperlayer()
            }
            
            // Add new layer
            if let newLayer = previewLayer {
                newLayer.frame = bounds
                layer.addSublayer(newLayer)
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
