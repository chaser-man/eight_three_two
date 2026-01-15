//
//  VideoDetailView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI
import AVKit

struct VideoDetailView: View {
    let video: Video
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                    }
            } else {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.black)
                }
                .onAppear {
                    player = AVPlayer(url: URL(string: video.videoURL)!)
                }
            }
        }
    }
}
