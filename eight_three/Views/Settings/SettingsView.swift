//
//  SettingsView.swift
//  eight_three
//
//  Created for Eight App
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAccountAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    NavigationLink("Edit Profile") {
                        EditProfileView()
                    }
                }
                
                Section("Privacy") {
                    // Privacy settings can be added here
                    Text("Who can see my videos")
                    Text("Who can respond to my videos")
                }
                
                Section("Notifications") {
                    // Notification settings can be added here
                    Toggle("Like/Dislike Notifications", isOn: .constant(true))
                    Toggle("New Follower Notifications", isOn: .constant(true))
                    Toggle("Response Notifications", isOn: .constant(true))
                }
                
                Section("App") {
                    Text("Data Usage: WiFi Only")
                    Text("Clear Cache")
                    Text("Version 1.0.0")
                }
                
                Section {
                    Button(role: .destructive, action: {
                        showingLogoutAlert = true
                    }) {
                        Text("Logout")
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteAccountAlert = true
                    }) {
                        Text("Delete Account")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    do {
                        try authService.signOut()
                    } catch {
                        print("Error signing out: \(error)")
                    }
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    // Implement account deletion
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Display Name") {
                    TextField("Display Name", text: $displayName)
                }
                
                Section("Bio") {
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            if let user = authService.currentUser {
                displayName = user.displayName
                bio = user.bio ?? ""
            }
        }
    }
    
    private func saveProfile() async {
        guard var user = authService.currentUser else { return }
        
        isLoading = true
        
        user.displayName = displayName
        user.bio = bio.isEmpty ? nil : bio
        
        do {
            let userService = UserService()
            try await userService.updateUser(user)
            authService.currentUser = user
            dismiss()
        } catch {
            print("Error updating profile: \(error)")
        }
        
        isLoading = false
    }
}
