//
//  ARTestView.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/26/26.
//

import SwiftUI
import SnapCoreEngine
import SharpOnPhoneUI

struct ARTestView: View {
    @State private var manager = ARSessionManager()
    
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
