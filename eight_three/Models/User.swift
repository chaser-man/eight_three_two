//
//  User.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    let id: String
    let email: String // washk12.org email
    var displayName: String
    var profilePictureURL: String?
    let school: School
    let grade: Grade
    var bio: String?
    let createdAt: Timestamp
    var followerCount: Int
    var followingCount: Int
    var videoCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case profilePictureURL
        case school
        case grade
        case bio
        case createdAt
        case followerCount
        case followingCount
        case videoCount
    }
    
    init(id: String, email: String, displayName: String, profilePictureURL: String? = nil, school: School, grade: Grade, bio: String? = nil, createdAt: Timestamp = Timestamp(), followerCount: Int = 0, followingCount: Int = 0, videoCount: Int = 0) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.profilePictureURL = profilePictureURL
        self.school = school
        self.grade = grade
        self.bio = bio
        self.createdAt = createdAt
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.videoCount = videoCount
    }
}

enum School: String, Codable, CaseIterable {
    case crimsonCliffs = "Crimson Cliffs"
    case desertHills = "Desert Hills"
    case dixie = "Dixie"
    case pineView = "Pine View"
    case snowCanyon = "Snow Canyon"
    case hurricane = "Hurricane"
    case enterprise = "Enterprise"
    case waterCanyon = "Water Canyon"
    case careerTech = "Career Tech"
    case other = "Other"
}

enum Grade: String, Codable, CaseIterable {
    case nine = "9"
    case ten = "10"
    case eleven = "11"
    case twelve = "12"
    case other = "Other"
}
