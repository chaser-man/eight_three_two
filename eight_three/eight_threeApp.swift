//
//  eight_threeApp.swift
//  eight_three
//
//  Created by Chase Nielsen on 1/13/26.
//

import SwiftUI
import FirebaseCore

@main
struct eight_threeApp: App {
    @StateObject private var authService = AuthService()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
        }
    }
}
