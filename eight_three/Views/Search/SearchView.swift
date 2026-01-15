//
//  SearchView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) var dismiss
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
                            Task {
                                await viewModel.searchUsers(
                                    query: searchText,
                                    school: selectedSchool,
                                    grade: selectedGrade
                                )
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
                            }
                        }
                        Button("All Schools") {
                            selectedSchool = nil
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
                            }
                        }
                        Button("All Grades") {
                            selectedGrade = nil
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
                
                // Results
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                    Spacer()
                    Text("No users found")
                        .foregroundColor(.secondary)
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ProfileHeaderView(user: user, viewModel: viewModel)
                ProfileStatsView(user: user)
                ProfileVideoGrid(userId: user.id, viewModel: viewModel)
            }
        }
        .navigationTitle(user.displayName)
        .task {
            await viewModel.loadUserVideos(userId: user.id)
        }
    }
}
