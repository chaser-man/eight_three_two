//
//  StorageService.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import FirebaseStorage
import UIKit

class StorageService {
    private let storage = Storage.storage()
    
    func uploadVideo(url: URL, userId: String, videoId: String) async throws -> String {
        let videoRef = storage.reference().child("videos/\(userId)/\(videoId).mp4")
        
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        _ = try await videoRef.putFileAsync(from: url, metadata: metadata)
        let downloadURL = try await videoRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    func uploadThumbnail(image: UIImage, userId: String, videoId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageConversionFailed
        }
        
        let thumbnailRef = storage.reference().child("thumbnails/\(userId)/\(videoId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await thumbnailRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await thumbnailRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    func uploadProfilePicture(image: UIImage, userId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageConversionFailed
        }
        
        let profileRef = storage.reference().child("profiles/\(userId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await profileRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await profileRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    func deleteVideo(userId: String, videoId: String) async throws {
        let videoRef = storage.reference().child("videos/\(userId)/\(videoId).mp4")
        try await videoRef.delete()
        
        let thumbnailRef = storage.reference().child("thumbnails/\(userId)/\(videoId).jpg")
        try? await thumbnailRef.delete() // Don't fail if thumbnail doesn't exist
    }
}

enum StorageError: LocalizedError {
    case imageConversionFailed
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to data"
        }
    }
}

// Extension to make Firebase Storage async/await compatible
extension StorageReference {
    func putFileAsync(from url: URL, metadata: StorageMetadata?) async throws -> StorageUploadTask {
        var uploadTask: StorageUploadTask!
        return try await withCheckedThrowingContinuation { continuation in
            uploadTask = self.putFile(from: url, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: uploadTask)
                }
            }
        }
    }
    
    func putDataAsync(_ uploadData: Data, metadata: StorageMetadata?) async throws -> StorageUploadTask {
        var uploadTask: StorageUploadTask!
        return try await withCheckedThrowingContinuation { continuation in
            uploadTask = self.putData(uploadData, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: uploadTask)
                }
            }
        }
    }
}
