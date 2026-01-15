//
//  ResponsesViewModel.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import SwiftUI

@MainActor
class ResponsesViewModel: ObservableObject {
    @Published var responses: [Video] = []
    @Published var isLoading = false
    
    private let videoService = VideoService()
    
    func loadResponses(videoId: String) async {
        isLoading = true
        
        do {
            responses = try await videoService.getVideoResponses(videoId: videoId)
        } catch {
            print("Error loading responses: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshResponse(responseId: String) async {
        do {
            if let updatedResponse = try await videoService.getVideo(videoId: responseId) {
                if let index = responses.firstIndex(where: { $0.id == responseId }) {
                    responses[index] = updatedResponse
                }
            }
        } catch {
            print("Error refreshing response: \(error)")
        }
    }
}
