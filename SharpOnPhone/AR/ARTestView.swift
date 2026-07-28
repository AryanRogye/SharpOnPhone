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
                    trackingState: manager.trackingState,
                    cameraPosition: manager.cameraPosition,
                    latestFrame: manager.latestFrame,
                    onCaptureCurrentFrame: manager.captureCurrentFrame,
                    onRestartBaseLocation: manager.runWorldTrackingSession
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
