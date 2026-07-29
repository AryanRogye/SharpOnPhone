//
//  ARSessionManager+Mesh.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/28/26.
//

import ARKit
import os
import SharpOnPhoneUI
import SharpOnPhoneModels

extension ARSessionManager {
    
    /// Internal helper for processing mesh anchors
    internal func processMeshAnchors(
        generation: UInt64,
        _ snapshots: [RecordedMeshAnchor]
    ) {
        guard
            isRecording,
            !isFinishingRecording,
            !isWaitingForTrackingReset,
            currentMeshCaptureGeneration() == generation
        else {
            return
        }
        
        for snapshot in snapshots {
            recordedMeshes[snapshot.identifier] = snapshot
        }
    }
    
    /// we just read the value and return the current captured value in the lock
    /// this really just looks like
    /// lock()
    /// let result = generation
    /// unlock()
    /// return result
    nonisolated internal func currentMeshCaptureGeneration() -> UInt64? {
        meshCaptureGeneration.withLock { state in
            guard state.isEnabled else {
                return nil
            }
            
            return state.generation
        }
    }
    
    /// increment is saved into the locks generation
    /// &+= is Swift's overflow tolerant addition, lets say we hit MAX
    /// on UInt64, this will wrap it back to 0
    @discardableResult
    nonisolated internal func beginMeshCapture() -> UInt64 {
        meshCaptureGeneration.withLock { state in
            state.isEnabled = true
            state.generation &+= 1
            return state.generation
        }
    }
    
    nonisolated internal func endMeshCapture() {
        meshCaptureGeneration.withLock { state in
            state.isEnabled = false
            state.generation &+= 1
        }
    }
}
