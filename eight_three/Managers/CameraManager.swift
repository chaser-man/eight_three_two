//
//  CameraManager.swift
//  eight_three
//
//  Created for Eight App
//

import Foundation
import AVFoundation
import UIKit

class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordedDuration: TimeInterval = 0
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var errorMessage: String?
    @Published var isSessionReady = false
    
    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var videoDevice: AVCaptureDevice?
    private var currentZoomFactor: CGFloat = 1.0
    internal var minZoomFactor: CGFloat = 1.0
    internal var maxZoomFactor: CGFloat = 10.0
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    private var outputFileURL: URL?
    private var hasCalledCallback = false
    private var isFirstRecording = true
    private var hasCompletedRecording = false
    private var isWarmingUp = false
    private var warmupCompletion: (() -> Void)?
    private var isStopping = false  // Prevent multiple stop calls
    var onRecordingFinished: ((URL) -> Void)?
    
    let maxRecordingDuration: TimeInterval = 8.0
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func setupCamera() {
        captureSession.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            errorMessage = "Camera not available"
            return
        }
        
        self.videoDevice = device
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            
            // Set max zoom to device max or 10x, whichever is smaller
            let deviceMaxZoom = device.activeFormat.videoMaxZoomFactor
            maxZoomFactor = min(deviceMaxZoom, 10.0)
            
            // Setup video output
            let movieOutput = AVCaptureMovieFileOutput()
            if captureSession.canAddOutput(movieOutput) {
                captureSession.addOutput(movieOutput)
                videoOutput = movieOutput
            }
            
            // Setup audio input
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                errorMessage = "Microphone not available"
                return
            }
            
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }
            
            // Setup preview layer
            let preview = AVCaptureVideoPreviewLayer(session: captureSession)
            preview.videoGravity = .resizeAspectFill
            previewLayer = preview
            
        } catch {
            errorMessage = "Failed to setup camera: \(error.localizedDescription)"
        }
    }
    
    func startSession() {
        if !captureSession.isRunning {
            // Request camera permission first
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self = self else { return }
                    self.captureSession.startRunning()
                    
                    // Wait for session to stabilize, then warm up the output
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self else { return }
                        // Verify session is running and output is available
                        if self.captureSession.isRunning && self.videoOutput != nil {
                            // Warm up the output by doing a very brief recording
                            // This initializes the file writing pipeline
                            self.warmUpOutput { [weak self] in
                                guard let self = self else { return }
                                self.isSessionReady = true
                                print("Camera session is ready and warmed up")
                            }
                        }
                    }
                }
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    if granted {
                        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                            guard let self = self else { return }
                            self.captureSession.startRunning()
                            
                            // Wait for session to stabilize, then warm up the output
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                guard let self = self else { return }
                                if self.captureSession.isRunning && self.videoOutput != nil {
                                    // Warm up the output by doing a very brief recording
                                    self.warmUpOutput { [weak self] in
                                        guard let self = self else { return }
                                        self.isSessionReady = true
                                        print("Camera session is ready and warmed up")
                                    }
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self?.errorMessage = "Camera permission denied"
                        }
                    }
                }
            default:
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "Camera access denied. Please enable it in Settings."
                }
            }
        } else {
            // Session already running, mark as ready
            if videoOutput != nil {
                isSessionReady = true
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.stopRunning()
            }
        }
    }
    
    func startRecording() throws {
        guard let videoOutput = videoOutput else {
            throw CameraError.outputNotAvailable
        }
        
        guard !isRecording else { return }
        
        // Don't allow recording during warmup
        guard !isWarmingUp else {
            throw CameraError.sessionNotReady
        }
        
        // Ensure session is running and ready before starting recording
        guard captureSession.isRunning && isSessionReady else {
            throw CameraError.sessionNotReady
        }
        
        // Reset callback flag and stopping flag
        hasCalledCallback = false
        isStopping = false
        
        // Track if this is the first recording (needs extra time for file writing)
        let isFirstRecordingAttempt = isFirstRecording
        if isFirstRecording {
            isFirstRecording = false
        }
        
        // Create temporary file URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        outputFileURL = documentsPath.appendingPathComponent("recording_\(UUID().uuidString).mp4")
        
        guard let outputURL = outputFileURL else {
            throw CameraError.fileCreationFailed
        }
        
        // Remove file if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        videoOutput.maxRecordedDuration = CMTime(seconds: maxRecordingDuration, preferredTimescale: 600)
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        
        isRecording = true
        recordingStartTime = Date()
        recordedDuration = 0
        
        // Start timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.recordedDuration = Date().timeIntervalSince(startTime)
            
            if self.recordedDuration >= self.maxRecordingDuration {
                self.stopRecording()
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { 
            print("stopRecording called but isRecording is false")
            return 
        }
        
        guard !isStopping else {
            print("stopRecording already in progress - ignoring duplicate call")
            return
        }
        
        isStopping = true
        print("stopRecording called - stopping video output")
        
        // Store the URL before stopping
        let url = outputFileURL
        
        // Stop the recording - this will trigger the delegate callback
        videoOutput?.stopRecording()
        
        // Stop the timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Don't set isRecording = false yet - wait for delegate to confirm
        // This prevents the button from being clickable again too soon
        
        // For early stops, wait longer for the file to be written
        // The delegate will be called, but we also set up a fallback in case delegate fails
        if let url = url {
            // Use a longer delay for early stops to ensure file is fully written
            // First recording needs even more time
            let isFirstRecordingAttempt = !hasCompletedRecording
            let fallbackDelay: TimeInterval = isFirstRecordingAttempt ? 2.0 : 1.0
            print("Setting up fallback callback with delay: \(fallbackDelay) seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + fallbackDelay) { [weak self] in
                guard let self = self, !self.hasCalledCallback else { 
                    print("Fallback skipped - callback already called")
                    return 
                }
                
                print("Fallback callback executing - checking file: \(url.path)")
                
                // Check if file exists and is readable
                if FileManager.default.fileExists(atPath: url.path) {
                    // Verify file is not empty (has content)
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                       let fileSize = attributes[.size] as? Int64, fileSize > 1000 { // At least 1KB
                        print("Fallback callback triggered for: \(url.path), size: \(fileSize) bytes")
                        self.hasCalledCallback = true
                        self.isRecording = false  // Now safe to set to false
                        self.isStopping = false  // Reset stopping flag
                        self.onRecordingFinished?(url)
                    } else {
                        print("File too small, retrying...")
                        // File exists but is too small, wait a bit more
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            guard let self = self, !self.hasCalledCallback else { return }
                            if FileManager.default.fileExists(atPath: url.path),
                               let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                               let fileSize = attributes[.size] as? Int64, fileSize > 1000 {
                                print("Fallback retry successful: \(url.path), size: \(fileSize) bytes")
                                self.hasCalledCallback = true
                                self.isRecording = false
                                self.isStopping = false
                                self.onRecordingFinished?(url)
                            } else {
                                print("Fallback retry failed - file still invalid")
                                self.isRecording = false  // Reset even on failure
                                self.isStopping = false
                            }
                        }
                    }
                } else {
                    print("File doesn't exist, retrying...")
                    // File doesn't exist yet, wait a bit more
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self, !self.hasCalledCallback else { return }
                        if FileManager.default.fileExists(atPath: url.path),
                           let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                           let fileSize = attributes[.size] as? Int64, fileSize > 1000 {
                            print("Fallback retry successful: \(url.path), size: \(fileSize) bytes")
                            self.hasCalledCallback = true
                            self.isRecording = false
                            self.isStopping = false
                            self.onRecordingFinished?(url)
                        } else {
                            print("Fallback retry failed - file still doesn't exist")
                            self.isRecording = false  // Reset even on failure
                            self.isStopping = false
                        }
                    }
                }
            }
        } else {
            print("No output URL stored - cannot set up fallback")
            isRecording = false
            isStopping = false
        }
    }
    
    func setZoom(factor: CGFloat) {
        guard let device = videoDevice else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            let clampedFactor = max(minZoomFactor, min(factor, maxZoomFactor))
            device.videoZoomFactor = clampedFactor
            currentZoomFactor = clampedFactor
            device.unlockForConfiguration()
        } catch {
            print("Error setting zoom: \(error)")
        }
    }
    
    func getRecordedVideoURL() -> URL? {
        return outputFileURL
    }
    
    /// Warms up the AVCaptureMovieFileOutput by doing a very brief recording
    /// This initializes the file writing pipeline so the first real recording works properly
    private func warmUpOutput(completion: @escaping () -> Void) {
        guard let videoOutput = videoOutput, captureSession.isRunning else {
            completion()
            return
        }
        
        isWarmingUp = true
        warmupCompletion = completion
        
        // Create a temporary file for warm-up
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let warmupURL = documentsPath.appendingPathComponent("warmup_\(UUID().uuidString).mp4")
        
        // Remove file if it exists
        try? FileManager.default.removeItem(at: warmupURL)
        
        // Start a very brief recording (0.2 seconds) to initialize the output
        videoOutput.maxRecordedDuration = CMTime(seconds: 0.2, preferredTimescale: 600)
        videoOutput.startRecording(to: warmupURL, recordingDelegate: self)
        
        // Auto-stop after 0.2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self, self.isWarmingUp else { return }
            videoOutput.stopRecording()
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Handle warmup recording separately
            if self.isWarmingUp {
                // For warmup, we just need to wait for the file to be written, then discard it
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }
                    // Delete warmup file
                    try? FileManager.default.removeItem(at: outputFileURL)
                    // Mark warmup as complete
                    self.isWarmingUp = false
                    // DON'T set hasCompletedRecording = true here - warmup doesn't count as a real recording
                    // Call completion
                    self.warmupCompletion?()
                    self.warmupCompletion = nil
                }
                return
            }
            
            // When stopping early, AVFoundation may report an error, but the file might still be valid
            // We'll check the file validity regardless of the error
            let hadError = error != nil
            if hadError {
                print("Recording delegate called with error: \(error!.localizedDescription)")
                // Don't set errorMessage yet - check if file is valid first
            }
            
            // Wait a bit for the file to be fully written, especially for early stops
            // Early stops need more time because the file is still being written
            // First recording needs extra time
            let isFirstRecordingAttempt = !self.hasCompletedRecording
            let waitTime: TimeInterval = {
                if isFirstRecordingAttempt {
                    return hadError ? 1.2 : 0.6  // Extra time for first recording
                } else {
                    return hadError ? 0.8 : 0.3
                }
            }()
            
            print("Delegate called - hadError: \(hadError), waitTime: \(waitTime), isFirstRecording: \(isFirstRecordingAttempt)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) { [weak self] in
                guard let self = self else { return }
                
                print("Delegate callback executing - checking file: \(outputFileURL.path)")
                
                // Verify file exists and is readable (even if there was an error)
                if FileManager.default.fileExists(atPath: outputFileURL.path) {
                    // Verify file has content (at least 1KB to ensure it's a valid video)
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: outputFileURL.path),
                       let fileSize = attributes[.size] as? Int64, fileSize > 1000 {
                        print("Recording finished successfully at: \(outputFileURL.path), size: \(fileSize) bytes")
                        // Prevent double-calling
                        if !self.hasCalledCallback {
                            self.hasCalledCallback = true
                            self.hasCompletedRecording = true  // Mark that we've successfully completed a recording
                            self.isRecording = false  // Now safe to set to false
                            self.isStopping = false  // Reset stopping flag
                            self.onRecordingFinished?(outputFileURL)
                        } else {
                            print("Callback already called - skipping")
                        }
                    } else {
                        print("Error: Recorded file is too small at: \(outputFileURL.path)")
                        // For early stops (when there was an error), wait a bit more and retry
                        if hadError && !self.hasCalledCallback {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                guard let self = self, !self.hasCalledCallback else { return }
                                if FileManager.default.fileExists(atPath: outputFileURL.path),
                                   let attributes = try? FileManager.default.attributesOfItem(atPath: outputFileURL.path),
                                   let fileSize = attributes[.size] as? Int64, fileSize > 1000 {
                                    print("Retry successful: \(outputFileURL.path), size: \(fileSize) bytes")
                                    self.hasCalledCallback = true
                                    self.hasCompletedRecording = true
                                    self.isRecording = false
                                    self.isStopping = false
                                    self.onRecordingFinished?(outputFileURL)
                                } else {
                                    print("Retry failed - file still invalid")
                                    self.isRecording = false
                                    self.isStopping = false
                                    self.errorMessage = "Recorded file is invalid"
                                }
                            }
                        } else {
                            self.isRecording = false
                            self.isStopping = false
                            self.errorMessage = "Recorded file is invalid"
                        }
                    }
                } else {
                    print("Error: Recorded file does not exist at: \(outputFileURL.path)")
                    // For early stops (when there was an error), wait a bit more and retry
                    if hadError && !self.hasCalledCallback {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            guard let self = self, !self.hasCalledCallback else { return }
                            if FileManager.default.fileExists(atPath: outputFileURL.path),
                               let attributes = try? FileManager.default.attributesOfItem(atPath: outputFileURL.path),
                               let fileSize = attributes[.size] as? Int64, fileSize > 1000 {
                                print("Retry successful: \(outputFileURL.path), size: \(fileSize) bytes")
                                self.hasCalledCallback = true
                                self.hasCompletedRecording = true
                                self.isRecording = false
                                self.isStopping = false
                                self.onRecordingFinished?(outputFileURL)
                            } else {
                                print("Retry failed - file still doesn't exist")
                                self.isRecording = false
                                self.isStopping = false
                                self.errorMessage = "Recorded file not found"
                            }
                        }
                    } else {
                        self.isRecording = false
                        self.isStopping = false
                        self.errorMessage = "Recorded file not found"
                    }
                }
            }
        }
    }
}

enum CameraError: LocalizedError {
    case outputNotAvailable
    case fileCreationFailed
    case sessionNotReady
    
    var errorDescription: String? {
        switch self {
        case .outputNotAvailable:
            return "Video output not available"
        case .fileCreationFailed:
            return "Failed to create output file"
        case .sessionNotReady:
            return "Camera session is not ready. Please wait a moment."
        }
    }
}
