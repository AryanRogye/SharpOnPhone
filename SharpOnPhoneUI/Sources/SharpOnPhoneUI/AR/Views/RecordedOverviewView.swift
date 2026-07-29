//
//  RecordedOverviewView.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/28/26.
//

import SharpOnPhoneModels
import SwiftUI
import AVKit

public struct RecordedOverviewView: View {
    
    let onRunSharp: (UIImage, Double) async throws -> SharpSplatBufferResource
    let savedProject: CameraInfoStore.SavedProject
    
    var cameraInfo: [ARCameraInfo] {
        savedProject.cameraInfo
    }
    
    @State private var playerController: ARVideoPlayerController
    @State private var showSaveRecording: Bool = false
    
    public init(
        onRunSharp: @escaping (UIImage, Double) async throws -> SharpSplatBufferResource,
        savedProject: CameraInfoStore.SavedProject,
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
    
    public var body: some View {
        VStack {
            ARVideoPlayer(controller: playerController)
            
            if let currentCameraInfo = playerController.currentCameraInfo {
                let transform = currentCameraInfo.cameraTransform
                
                let position = SIMD3<Float>(
                    transform.columns.3.x,
                    transform.columns.3.y,
                    transform.columns.3.z
                )
                
                VStack(alignment: .leading) {
                    Text("Time: \(currentCameraInfo.timestamp, format: .number.precision(.fractionLength(3)))")
                    Text("x: \(position.x)")
                    Text("y: \(position.y)")
                    Text("z: \(position.z)")
                    NavigationLink {
                        GaussianSplatRecontructionView(
                            onRunSharp: onRunSharp,
                            savedProject: savedProject
                        )
                    } label: {
                        Text("View Gaussian Splat")
                    }
                    .buttonStyle(.glassProminent)
                }
                .monospacedDigit()
            }
        }
    }
}
