//
//  ARSessionManager.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/26/26.
//

import ARKit
import Observation
import Metal
import SnapCoreEngine
import SharpOnPhoneUI

@Observable
@MainActor
final class ARSessionManager: NSObject {
    
    let session = ARSession()
    
    private let videoRecorder = ARVideoRecorder()

    var trackingState = "Not started"
    var cameraPosition: SIMD3<Float> = SIMD3<Float>.zero
    var imageTexture: YCbCrTextures?
    var latestFrame: ARCameraFrame?
    
    var isRecording = false
    var recordedVideoURL: URL?
    
    override init() {
        super.init()
        session.delegate = self
    }

    func startRecording() {
        let fileName = "ARCapture-\(UUID().uuidString).mov"
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        
        recordedVideoURL = nil
        isRecording = true
        
        videoRecorder.startRecording(to: url)
    }
    
    func stopRecording() {
        guard isRecording else {
            return
        }
        
        isRecording = false
        
        videoRecorder.stopRecording { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let url):
                    self.recordedVideoURL = url
                    print("Saved video to:", url)
                    
                case .failure(let error):
                    print("Recording failed:", error)
                }
            }
        }
    }
    
    func captureCurrentFrame() {
        guard let frame = session.currentFrame else {
            return
        }
        
        latestFrame = ARCameraFrame(
            image: frame.capturedImage,
            cameraTransform: frame.camera.transform,
            intrinsics: frame.camera.intrinsics,
            timestamp: frame.timestamp
        )
        
        do {
            imageTexture = try MetalHelpers.makeYCbCrTextures(
                from: frame.capturedImage
            )
        } catch {
            print("Texture creation failed:", error)
            imageTexture = nil
        }
    }
}

// MARK: - World Tracking Session
extension ARSessionManager {
    public func runWorldTrackingSession() {
        // check if supported
        guard ARWorldTrackingConfiguration.isSupported else {
            trackingState = "World tracking is unsupported"
            return
        }
        
        // if allowed we set it
        let configuration = ARWorldTrackingConfiguration()
        
        // use the camera plus motion sensors to estimate where the phone is
        configuration.worldAlignment = .gravity
        
        session.run(
            configuration,
            options: [.resetTracking, .removeExistingAnchors]
        )
    }
    
    public func stopWorldTrackingSession() {
        session.pause()
    }
}

extension ARSessionManager: ARSessionDelegate {
    
    nonisolated func session(
        _ session: ARSession,
        didUpdate frame: ARFrame
    ) {
        let transform = frame.camera.transform
        
        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        
        let trackingDescription: String
        
        switch frame.camera.trackingState {
        case .normal:
            trackingDescription = "Normal"
            
        case .notAvailable:
            trackingDescription = "Unavailable"
            
        case .limited(let reason):
            trackingDescription = "Limited: \(reason)"
            
        @unknown default:
            trackingDescription = "Unknown"
        }
        
        let textures: YCbCrTextures?
        
        do {
            textures = try MetalHelpers.makeYCbCrTextures(
                from: frame.capturedImage
            )
        } catch {
            print("Texture creation failed:", error)
            textures = nil
        }
        
        Task { @MainActor in
            imageTexture = textures
            cameraPosition = position
            trackingState = trackingDescription
        }
    }
}
