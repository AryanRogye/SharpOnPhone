//
//  GaussianSplatRecontructionView.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/28/26.
//

import SwiftUI
import SharpOnPhoneModels

struct GaussianSplatRecontructionView: View {
    
    let onRunSharp: (UIImage, Double) async throws -> SharpSplatBufferResource
    let savedProject: CameraInfoStore.SavedProject
    
    @State private var playerController: ARVideoPlayerController
    
    init(
        onRunSharp: @escaping (UIImage, Double) async throws -> SharpSplatBufferResource,
        savedProject: CameraInfoStore.SavedProject
    ) {
        self.onRunSharp = onRunSharp
        self.savedProject = savedProject
        _playerController = State(
            initialValue: ARVideoPlayerController(
                url: savedProject.videoURL,
                cameraInfo: savedProject.cameraInfo
            )
        )
    }
    
    var body: some View {
        VStack {
            ARVideoPlayer(controller: playerController)
        }
    }
}
