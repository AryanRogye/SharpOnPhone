//
//  ARSessionManager.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/26/26.
//

import ARKit
import Observation
import Metal
import os
import SnapCoreEngine
import SharpOnPhoneUI
import SharpOnPhoneModels

@Observable
@MainActor
final class ARSessionManager: NSObject {
    
    let session = ARSession()
    
    internal let videoRecorder = ARVideoRecorder()

    var trackingState = "Not started"
    var cameraPosition: SIMD3<Float> = SIMD3<Float>.zero
    var imageTexture: YCbCrTextures?
    var cameraInfo: [ARCameraInfo] = []
    var recordedMeshes: [UUID: RecordedMeshAnchor] = [:]
    
    var isRecording = false
    var recordedVideoURL: URL?

    internal var isWaitingForTrackingReset = false
    internal var isFinishingRecording = false
    internal var resetFrameTimestamp: TimeInterval = -.infinity
    internal var lastSubmittedFrameTimestamp: TimeInterval?
    internal var pendingRecordingURL: URL?
    internal var recordingID: UUID?
    
    internal struct MeshCaptureState: Sendable {
        var generation: UInt64 = 0
        var isEnabled = false
        
        nonisolated init() {
            self.generation = 0
            self.isEnabled = false
        }
    }

    /// lock owns a UInt64 initially with 0
    /// the whole purpose of this is to avoid stale AR Mesh callbacks from
    /// entering the current recording
    internal nonisolated let meshCaptureGeneration = OSAllocatedUnfairLock(
        initialState: MeshCaptureState()
    )
    
    override init() {
        super.init()
        session.delegate = self
    }
    
}
