//
//  CameraViewModel.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import SwiftUI

@MainActor
class CameraViewModel: ObservableObject {
    @Published var errorMessage: String?
}
