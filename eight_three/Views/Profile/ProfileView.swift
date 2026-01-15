//
//  ProfileView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingSettings = false
    @State private var showingSearch = false
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let user = authService.currentUser {
                        ProfileHeaderView(user: user, viewModel: viewModel)
                        
                        ProfileStatsView(user: user)
                        
                        ProfileVideoGrid(userId: user.id, viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSearch = true
                    }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingSearch) {
                SearchView()
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
        }
        .task {
            if let userId = authService.currentUser?.id {
                await viewModel.loadUserVideos(userId: userId)
            }
        }
    }
}

struct ProfileHeaderView: View {
    let user: User
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var authService: AuthService
    @State private var showingImagePicker = false
    
    // Check if this is the current user's profile
    private var isCurrentUser: Bool {
        authService.currentUser?.id == user.id
    }
    
    // Use current user data if viewing own profile, otherwise use passed user
    private var displayUser: User {
        if isCurrentUser, let currentUser = authService.currentUser {
            return currentUser
        }
        return user
    }
    
    var body: some View {
        VStack(spacing: 15) {
            Button(action: {
                if isCurrentUser {
                    showingImagePicker = true
                }
            }) {
                ZStack {
                    if let profilePictureURL = displayUser.profilePictureURL,
                       let url = URL(string: profilePictureURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // Loading indicator when uploading
                    if viewModel.isLoading {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 100, height: 100)
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    }
                }
            }
            .disabled(!isCurrentUser)
            .opacity(isCurrentUser ? 1.0 : 0.8)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: Binding(
                    get: { nil },
                    set: { newImage in
                        if let newImage = newImage {
                            Task {
                                await viewModel.updateProfilePicture(image: newImage, authService: authService)
                            }
                        }
                    }
                ))
            }
            
            Text(displayUser.displayName)
                .font(.system(size: 24, weight: .semibold))
            
            if let bio = displayUser.bio {
                Text(bio)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Text("\(displayUser.school.rawValue) • Grade \(displayUser.grade.rawValue)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            // Show error message if profile picture upload failed
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
        .onChange(of: authService.currentUser?.profilePictureURL) { oldValue, newValue in
            // Clear error when profile picture updates successfully
            if newValue != nil && newValue != oldValue {
                viewModel.errorMessage = nil
            }
        }
    }
}

struct ProfileStatsView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 40) {
            VStack {
                Text("\(user.followingCount)")
                    .font(.system(size: 24, weight: .bold))
                Text("Following")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            VStack {
                Text("\(user.videoCount)")
                    .font(.system(size: 24, weight: .bold))
                Text("Videos")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            VStack {
                Text("\(user.followerCount)")
                    .font(.system(size: 24, weight: .bold))
                Text("Followers")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
    }
}

struct ProfileVideoGrid: View {
    let userId: String
    @ObservedObject var viewModel: ProfileViewModel
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(viewModel.userVideos) { video in
                NavigationLink(destination: VideoDetailView(video: video)) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(height: 120)
                    .clipped()
                    .overlay(
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                    )
                }
            }
        }
    }
}
