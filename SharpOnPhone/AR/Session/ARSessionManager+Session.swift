//
//  ARSessionManager+session.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/28/26.
//

import ARKit

extension ARSessionManager {
    
    /// function to start tracking
    public func runWorldTrackingSession() {
        // Allow:
        // 1. Normal session startup when not recording.
        // 2. The intentional reset performed by startRecording().
        //
        // Reject a manual reset during an active recording.
        guard !isRecording || isWaitingForTrackingReset else {
            return
        }

        // check if supported
        guard ARWorldTrackingConfiguration.isSupported else {
            trackingState = "World tracking is unsupported"
            return
        }
        
        // cancel all stale meshes
        endMeshCapture()
        
        // if allowed we set it
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(
            .meshWithClassification
        ) {
            configuration.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        // use the camera plus motion sensors to estimate where the phone is
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [
            .horizontal,
            .vertical
        ]
        
        session.run(
            configuration,
            options: [
                .resetTracking,
                .removeExistingAnchors
            ]
        )
    }
    
    /// function to stop world tracking
    public func stopWorldTrackingSession() {
        session.pause()
        stopRecording()
    }
}
