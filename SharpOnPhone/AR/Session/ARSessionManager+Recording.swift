//
//  ARSessionManager+Recording.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/28/26.
//

import Foundation
import ARKit
import SharpOnPhoneUI
import SharpOnPhoneModels

extension ARSessionManager {
    
    func startRecording() {
        
        // make sure we're not recording or finishing up a past recording
        guard !isRecording, !isFinishingRecording else {
            return
        }
        
        let fileName = "ARCapture-\(UUID().uuidString).mov"
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        
        prepareForRecording(with: url)
        
        // Freeze the old stream so every queued frame is at or before this
        // cutoff. Recording begins only after the reset produces a newer,
        // normally tracked frame.
        session.pause()
        resetFrameTimestamp = session.currentFrame?.timestamp ?? -.infinity
        isWaitingForTrackingReset = true
        isRecording = true
        runWorldTrackingSession()
    }
    
    func stopRecording() {
        // make sure stopRecording is only called when we're recording
        // and we havnt already tapped it
        guard isRecording, !isFinishingRecording else {
            return
        }
        
        // this only gets triggered if we start the recording and
        // stop it right away before the recording session starts
        // so we just reset all values
        if isWaitingForTrackingReset {
            cancelPendingRecording()
            return
        }
        
        // mark flag as finishing so we cant start again
        isFinishingRecording = true
        
        // everything captured under the previous generation is now stale
        // basically dont process it
        endMeshCapture()
        
        videoRecorder.stopRecording { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                // set flags
                self.isRecording = false
                self.isFinishingRecording = false
                self.lastSubmittedFrameTimestamp = nil
                
                switch result {
                case .success(let url):
                    self.recordedVideoURL = url
                    
                case .failure(_):
                    // do nothing on failure
                    return
                }
            }
        }
    }
    
    private func cancelPendingRecording() {
        endMeshCapture()
        isWaitingForTrackingReset = false
        self.isRecording = false
        pendingRecordingURL = nil
        recordingID = nil
        recordedVideoURL = nil
        cameraInfo = []
        recordedMeshes = [:]
    }
    
    private func prepareForRecording(with url: URL) {
        recordedVideoURL = nil
        cameraInfo = []
        recordedMeshes = [:]
        pendingRecordingURL = url
        recordingID = UUID()
        lastSubmittedFrameTimestamp = nil
    }
}
