//
//  SearchView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var selectedSchool: School? = nil
    @State private var selectedGrade: Grade? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search users...", text: $searchText)
                        .onSubmit {
                            performSearch()
                        }
                        .onChange(of: searchText) { oldValue, newValue in
                            // Debounce search - search after user stops typing for 0.5 seconds
                            Task {
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                if searchText == newValue {
                                    performSearch()
                                }
                            }
                        }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Filters
                HStack {
                    Menu {
                        ForEach(School.allCases, id: \.self) { school in
                            Button(school.rawValue) {
                                selectedSchool = school
                                performSearch()
                            }
                        }
                        Button("All Schools") {
                            selectedSchool = nil
                            performSearch()
                        }
                    } label: {
                        HStack {
                            Text(selectedSchool?.rawValue ?? "All Schools")
                            Image(systemName: "chevron.down")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Menu {
                        ForEach(Grade.allCases, id: \.self) { grade in
                            Button(grade.rawValue) {
                                selectedGrade = grade
                                performSearch()
                            }
                        }
                        Button("All Grades") {
                            selectedGrade = nil
                            performSearch()
                        }
                    } label: {
                        HStack {
                            Text(selectedGrade?.rawValue ?? "All Grades")
                            Image(systemName: "chevron.down")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Error message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Results
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.3")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "Start typing to search for users" : "No users found")
                            .foregroundColor(.secondary)
                        if !searchText.isEmpty {
                            Text("Try adjusting your filters or search term")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                } else {
                    List(viewModel.searchResults) { user in
                        NavigationLink(destination: UserProfileView(user: user)) {
                            UserSearchResultRow(user: user, viewModel: viewModel)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                // Set authService reference in viewModel
                viewModel.authService = authService
                // Perform initial search when view appears (show all users)
                performSearch()
            }
        }
    }
    
    private func performSearch() {
        Task {
            await viewModel.searchUsers(
                query: searchText,
                school: selectedSchool,
                grade: selectedGrade
            )
        }
    }
}

struct UserSearchResultRow: View {
    let user: User
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        HStack(spacing: 15) {
            if let profilePictureURL = user.profilePictureURL,
               let url = URL(string: profilePictureURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .medium))
                Text("\(user.school.rawValue) • Grade \(user.grade.rawValue)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let isFollowing = viewModel.followingStatus[user.id] {
                Button(action: {
                    Task {
                        await viewModel.toggleFollow(userId: user.id, isCurrentlyFollowing: isFollowing)
                    }
                }) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isFollowing ? .secondary : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 8)
        .task {
            await viewModel.checkFollowingStatus(userId: user.id)
        }
    }
}

struct UserProfileView: View {
    let user: User
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var followViewModel = SearchViewModel()
    @EnvironmentObject var authService: AuthService
    @State private var isFollowing: Bool?
    @State private var displayedUser: User // Track user with updated stats
    
    init(user: User) {
        self.user = user
        _displayedUser = State(initialValue: user)
    }
    
    private var isCurrentUser: Bool {
        authService.currentUser?.id == user.id
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ProfileHeaderView(user: displayedUser, viewModel: viewModel)
                
                // Follow button (only show if not current user)
                if !isCurrentUser, let followingStatus = isFollowing {
                    Button(action: {
                        Task {
                            await followViewModel.toggleFollow(userId: displayedUser.id, isCurrentlyFollowing: followingStatus)
                            await checkFollowingStatus()
                            await refreshUserData()
                        }
                    }) {
                        Text(followingStatus ? "Following" : "Follow")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(followingStatus ? .primary : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(followingStatus ? Color.gray.opacity(0.2) : Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                }
                
                ProfileStatsView(user: displayedUser)
                ProfileVideoGrid(userId: displayedUser.id, viewModel: viewModel)
            }
        }
        .navigationTitle(displayedUser.displayName)
        .task {
            // Set authService reference in followViewModel
            followViewModel.authService = authService
            await viewModel.loadUserVideos(userId: displayedUser.id)
            if !isCurrentUser {
                await checkFollowingStatus()
            }
            await refreshUserData()
        }
    }
    
    private func checkFollowingStatus() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        do {
            let following = try await UserService().isFollowing(followerId: currentUserId, followingId: displayedUser.id)
            await MainActor.run {
                isFollowing = following
            }
        } catch {
            print("Error checking follow status: \(error)")
        }
    }
    
    private func refreshUserData() async {
        do {
            // Refresh the displayed user's data
            if let updatedUser = try await UserService().getUser(userId: displayedUser.id) {
                await MainActor.run {
                    displayedUser = updatedUser
                }
            }
            
            // Also refresh the current user's data to update following count
            if let currentUserId = authService.currentUser?.id,
               let updatedCurrentUser = try await UserService().getUser(userId: currentUserId) {
                await MainActor.run {
                    authService.currentUser = updatedCurrentUser
                }
            }
        } catch {
            print("Error refreshing user data: \(error)")
        }
    }
}
