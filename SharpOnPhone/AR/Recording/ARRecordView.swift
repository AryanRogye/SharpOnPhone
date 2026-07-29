//
//  ARRecordView.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/28/26.
//

import SwiftUI
import SharpOnPhoneUI
import SharpOnPhoneModels

struct ARRecordView: View {
    
    @Bindable var manager: ARSessionManager
    @Binding var error: String?
    @Binding var showError: Bool
    let cameraInfoStore : CameraInfoStore
    
    @State private var isSaving: Bool = false
    
    var body: some View {
        ZStack {
            if let texture = manager.imageTexture {
                ARCameraView(texture: texture)
                ARInfoView(
                    startedRecording: manager.isRecording,
                    trackingState: manager.trackingState,
                    cameraPosition: manager.cameraPosition,
                    recordedVideoURL: manager.recordedVideoURL,
                    cameraInfo: manager.cameraInfo,
                    recordedMeshes: manager.recordedMeshes,
                    onRestartBaseLocation: manager.runWorldTrackingSession,
                    onToggleRecording: {
                        if manager.isRecording {
                            manager.stopRecording()
                        } else {
                            // we restart the world tracking session so its (0,0,0) from
                            // where we start recording
                            manager.startRecording()
                        }
                    },
                    onSave: { name in
                        if isSaving { return }
                        guard let url = manager.recordedVideoURL else { return }
                        Task {
                            isSaving = true
                            defer { isSaving = false }
                            do {
                                try await cameraInfoStore.createNewProject(
                                    named: name,
                                    withInfo: manager.cameraInfo,
                                    videoUrl: url
                                )
                            } catch {
                                self.error = error.localizedDescription
                                self.showError = true
                            }
                        }
                    }
                )
            } else {
                Text("Loading AR Camera")
                    .font(.title)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            manager.runWorldTrackingSession()
        }
        .onDisappear {
            manager.stopWorldTrackingSession()
        }
    }
}
