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
                    ZStack {
                        if let player = viewModel.player {
                            VideoPlayer(player: player)
                                .frame(height: 400)
                                .onAppear {
                                    player.play()
                                    // Loop the video within trim range
                                    NotificationCenter.default.addObserver(
                                        forName: .AVPlayerItemDidPlayToEndTime,
                                        object: player.currentItem,
                                        queue: .main
                                    ) { _ in
                                        if let trimRange = viewModel.trimRange, trimRange.isValid {
                                            player.seek(to: CMTime(seconds: trimRange.startTime, preferredTimescale: 600))
                                        } else {
                                            player.seek(to: .zero)
                                        }
                                        player.play()
                                    }
                                    
                                    // Set initial playback position if trimmed
                                    if let trimRange = viewModel.trimRange, trimRange.isValid {
                                        player.seek(to: CMTime(seconds: trimRange.startTime, preferredTimescale: 600))
                                    }
                                }
                            
                            // Text overlay preview
                            if let textOverlay = viewModel.textOverlay, !textOverlay.text.isEmpty {
                                Text(textOverlay.text)
                                    .font(.system(size: textOverlay.fontSize))
                                    .foregroundColor(Color(textOverlay.color.uiColor))
                                    .multilineTextAlignment(textOverlay.alignment == .center ? .center : (textOverlay.alignment == .left ? .leading : .trailing))
                                    .padding()
                                    .position(
                                        x: textOverlay.positionX * UIScreen.main.bounds.width,
                                        y: textOverlay.positionY * 400
                                    )
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
                    }
                    .frame(height: 400)
                    
                    // Export progress
                    if viewModel.isExporting {
                        VStack(spacing: 8) {
                            ProgressView(value: viewModel.exportProgress)
                            Text("Processing video... \(Int(viewModel.exportProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Editing Controls
                    VStack(spacing: 20) {
                        // Text Overlay Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Text Overlay")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    if viewModel.textOverlay == nil {
                                        viewModel.textOverlay = TextOverlay()
                                    }
                                    viewModel.isEditingText.toggle()
                                }) {
                                    Text(viewModel.isEditingText ? "Done" : "Add Text")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if viewModel.isEditingText {
                                TextEditorView(textOverlay: Binding(
                                    get: { viewModel.textOverlay ?? TextOverlay() },
                                    set: { viewModel.textOverlay = $0 }
                                ))
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Video Trimming Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Trim Video")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    viewModel.isTrimming.toggle()
                                }) {
                                    Text(viewModel.isTrimming ? "Done" : "Trim")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if viewModel.isTrimming, let trimRange = viewModel.trimRange {
                                VideoTrimView(trimRange: Binding(
                                    get: { trimRange },
                                    set: { viewModel.trimRange = $0 }
                                ), videoDuration: viewModel.videoDuration)
                            } else if let trimRange = viewModel.trimRange {
                                Text("Duration: \(String(format: "%.1f", trimRange.duration))s")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        
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

// Text Editor View
struct TextEditorView: View {
    @Binding var textOverlay: TextOverlay
    
    var body: some View {
        VStack(spacing: 15) {
            // Text input
            TextField("Enter text", text: $textOverlay.text)
                .textFieldStyle(.roundedBorder)
            
            // Position controls
            VStack(alignment: .leading, spacing: 8) {
                Text("Position")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("X: \(Int(textOverlay.positionX * 100))%")
                        .font(.caption)
                    Slider(value: $textOverlay.positionX, in: 0...1)
                        .frame(width: 150)
                }
                
                HStack {
                    Text("Y: \(Int(textOverlay.positionY * 100))%")
                        .font(.caption)
                    Slider(value: $textOverlay.positionY, in: 0...1)
                        .frame(width: 150)
                }
            }
            
            // Font size
            VStack(alignment: .leading, spacing: 8) {
                Text("Size: \(Int(textOverlay.fontSize))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Slider(value: $textOverlay.fontSize, in: 20...80)
            }
            
            // Color picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack {
                    ForEach([TextOverlay.TextColor.white, .black, .red, .blue, .yellow, .green], id: \.self) { color in
                        Button(action: {
                            textOverlay.color = color
                        }) {
                            Circle()
                                .fill(Color(color.uiColor))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(textOverlay.color == color ? Color.blue : Color.clear, lineWidth: 3)
                                )
                        }
                    }
                }
            }
            
            // Alignment
            VStack(alignment: .leading, spacing: 8) {
                Text("Alignment")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("Alignment", selection: $textOverlay.alignment) {
                    Text("Left").tag(TextOverlay.TextAlignment.left)
                    Text("Center").tag(TextOverlay.TextAlignment.center)
                    Text("Right").tag(TextOverlay.TextAlignment.right)
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// Video Trim View
struct VideoTrimView: View {
    @Binding var trimRange: TrimRange
    let videoDuration: Double
    
    // Use local state to prevent slider ranges from changing during drag
    @State private var startTimeValue: Double
    @State private var endTimeValue: Double
    
    init(trimRange: Binding<TrimRange>, videoDuration: Double) {
        self._trimRange = trimRange
        self.videoDuration = videoDuration
        _startTimeValue = State(initialValue: trimRange.wrappedValue.startTime)
        _endTimeValue = State(initialValue: trimRange.wrappedValue.endTime)
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // Duration display
            HStack {
                Text("Start: \(String(format: "%.1f", trimRange.startTime))s")
                    .font(.caption)
                Spacer()
                Text("End: \(String(format: "%.1f", trimRange.endTime))s")
                    .font(.caption)
                Spacer()
                Text("Duration: \(String(format: "%.1f", trimRange.duration))s")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            // Trim controls
            VStack(spacing: 10) {
                // Start time
                VStack(alignment: .leading, spacing: 5) {
                    Text("Start Time")
                        .font(.subheadline)
                    Slider(value: $startTimeValue, in: 0...min(videoDuration, 8.0))
                        .onChange(of: startTimeValue) { oldValue, newValue in
                            // Clamp to ensure minimum 0.5s gap
                            let maxStart = trimRange.endTime - 0.5
                            if newValue > maxStart {
                                startTimeValue = maxStart
                            }
                            trimRange.startTime = startTimeValue
                        }
                }
                
                // End time
                VStack(alignment: .leading, spacing: 5) {
                    Text("End Time")
                        .font(.subheadline)
                    Slider(value: $endTimeValue, in: 0...min(videoDuration, 8.0))
                        .onChange(of: endTimeValue) { oldValue, newValue in
                            // Clamp to ensure minimum 0.5s gap
                            let minEnd = trimRange.startTime + 0.5
                            if newValue < minEnd {
                                endTimeValue = minEnd
                            }
                            trimRange.endTime = endTimeValue
                        }
                }
            }
            
            // Quick trim buttons
            HStack(spacing: 10) {
                Button("Full Video") {
                    let newRange = TrimRange(startTime: 0, endTime: min(videoDuration, 8.0))
                    trimRange = newRange
                    startTimeValue = newRange.startTime
                    endTimeValue = newRange.endTime
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                Button("First 8s") {
                    let newRange = TrimRange(startTime: 0, endTime: min(8.0, videoDuration))
                    trimRange = newRange
                    startTimeValue = newRange.startTime
                    endTimeValue = newRange.endTime
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .onChange(of: trimRange.startTime) { oldValue, newValue in
            // Sync local state when trimRange changes externally
            if abs(startTimeValue - newValue) > 0.01 {
                startTimeValue = newValue
            }
        }
        .onChange(of: trimRange.endTime) { oldValue, newValue in
            // Sync local state when trimRange changes externally
            if abs(endTimeValue - newValue) > 0.01 {
                endTimeValue = newValue
            }
        }
    }
}
