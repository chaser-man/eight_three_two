//
//  ResponsesView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI
import AVKit
import FirebaseAuth

struct ResponsesView: View {
    let videoId: String
    @StateObject private var viewModel = ResponsesViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showingResponseRecording = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.responses) { response in
                        ResponseVideoPlayer(
                            response: response,
                            viewModel: viewModel
                        )
                        .frame(height: UIScreen.main.bounds.height)
                    }
                }
            }
            .navigationTitle("Responses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Record Response") {
                        showingResponseRecording = true
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingResponseRecording) {
                ResponseRecordingView(parentVideoId: videoId)
            }
            .task {
                await viewModel.loadResponses(videoId: videoId)
            }
        }
    }
}

struct ResponseVideoPlayer: View {
    let response: Video
    @ObservedObject var viewModel: ResponsesViewModel
    @State private var player: AVPlayer?
    @State private var showingNestedResponses = false
    @State private var showingNestedResponseRecording = false
    @State private var userInteraction: InteractionType?
    
    var body: some View {
        ZStack {
            // Video Player
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                AsyncImage(url: URL(string: response.thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.black)
                        .overlay(ProgressView().tint(.white))
                }
                .onAppear {
                    loadVideo()
                }
            }
            
            // Overlay Controls
            VStack {
                Spacer()
                
                HStack {
                    // Left side - Like/Dislike
                    VStack(spacing: 20) {
                        Button(action: {
                            Task {
                                await toggleLike()
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: userInteraction == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .font(.system(size: 30))
                                    .foregroundColor(userInteraction == .like ? .blue : .white)
                                Text("\(response.likeCount)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            Task {
                                await toggleDislike()
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: userInteraction == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                    .font(.system(size: 30))
                                    .foregroundColor(userInteraction == .dislike ? .red : .white)
                                Text("\(response.dislikeCount)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 30)
                    
                    Spacer()
                    
                    // Right side - Response buttons
                    VStack(spacing: 20) {
                        Button(action: {
                            showingNestedResponseRecording = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                Text("Record Wave")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            showingNestedResponses = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "bubble.right.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                Text("\(response.responseCount)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Text("View Waves")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .fullScreenCover(isPresented: $showingNestedResponses) {
            ResponsesView(videoId: response.id)
        }
        .fullScreenCover(isPresented: $showingNestedResponseRecording) {
            ResponseRecordingView(parentVideoId: response.id)
        }
        .task {
            await checkUserInteraction()
        }
    }
    
    private func loadVideo() {
        player = AVPlayer(url: URL(string: response.videoURL)!)
        player?.isMuted = false
        player?.actionAtItemEnd = .none
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }
    
    private func toggleLike() async {
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        let interactionService = InteractionService()
        
        if userInteraction == .like {
            try? await interactionService.unlikeVideo(userId: userId, videoId: response.id)
            userInteraction = nil
        } else {
            try? await interactionService.likeVideo(userId: userId, videoId: response.id)
            userInteraction = .like
        }
        
        await viewModel.refreshResponse(responseId: response.id)
    }
    
    private func toggleDislike() async {
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        let interactionService = InteractionService()
        
        if userInteraction == .dislike {
            try? await interactionService.undislikeVideo(userId: userId, videoId: response.id)
            userInteraction = nil
        } else {
            try? await interactionService.dislikeVideo(userId: userId, videoId: response.id)
            userInteraction = .dislike
        }
        
        await viewModel.refreshResponse(responseId: response.id)
    }
    
    private func checkUserInteraction() async {
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        let interactionService = InteractionService()
        if let interaction = try? await interactionService.getInteraction(userId: userId, videoId: response.id) {
            userInteraction = interaction.type
        }
    }
}
