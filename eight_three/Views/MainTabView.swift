//
//  MainTabView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0 // Start on Feed tab (0) instead of Camera (1)
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "house.fill")
                }
                .tag(0)
            
            CameraView()
                .tabItem {
                    Label("Camera", systemImage: "camera.fill")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(2)
        }
    }
}
