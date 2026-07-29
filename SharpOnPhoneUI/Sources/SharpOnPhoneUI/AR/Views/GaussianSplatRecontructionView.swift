//
//  GaussianSplatRecontructionView.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/28/26.
//

import SwiftUI
import SharpOnPhoneModels

struct PosedSplat {
    let resource: SharpSplatBufferResource
    let cameraInfo: ARCameraInfo
}

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
    
    @State private var error: String?
    @State private var showError: Bool = false
    @State private var isProcessing: Bool = false
    
    @State private var processedSplat: PosedSplat?
    
    var body: some View {
        VStack {
            ARVideoPlayer(controller: playerController)
            
            if let processedSplat {
                NavigationLink {
                    PosedSplatPreview(posedSplat: processedSplat)
                } label: {
                    Text("View Guassian Splat Reconstruction")
                }
                .buttonStyle(.glassProminent)
            }
            HStack {
                Button("Process") {
                    self.process()
                }
                .buttonStyle(.glassProminent)
                .disabled(isProcessing)
                Button("Step Forward") {
                    self.playerController.stepForward()
                }
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
    }
    
    private func process() {
        if isProcessing { return }
        Task { @MainActor in
            isProcessing = true
            defer { isProcessing = false }
            
            let image = await playerController.freezeAndCaptureCurrentFrame()
            
            if let cameraInfo = playerController.currentCameraInfo,
               let image {
                // The video's 90° preferred transform maps the camera's vertical
                // focal length (fy) onto the displayed image's horizontal axis.
                let focalLength = cameraInfo.intrinsics.columns.1.y
                let disparityFactor =
                    Double(focalLength) / Double(image.size.width)
                processedSplat = nil
                
                do {
                    let resource = try await onRunSharp(image, disparityFactor)
                    processedSplat = .init(resource: resource, cameraInfo: cameraInfo)
                } catch {
                    self.error = error.localizedDescription
                    self.showError = true
                }
            } else {
                self.error = "CurrentCameraInfo Nil: \(playerController.currentCameraInfo == nil), CurrentFrame Nil: \(playerController.currentFrame == nil)"
                self.showError = true
                self.playerController.stepForward()
            }
        }
    }
}

import RealityKit

struct PosedSplatPreview: View {
    
    let posedSplat: PosedSplat
    @State private var cameraController: RealityKitTraverseCameraController

    init(posedSplat: PosedSplat) {
        self.posedSplat = posedSplat
        _cameraController = State(
            initialValue: RealityKitTraverseCameraController(
                cameraInfo: [posedSplat.cameraInfo]
            )
        )
    }
    
    // The recorded video is presented 90° clockwise before SHARP processes
    // it. Rotate that portrait image frame back into ARKit's camera frame,
    // then convert SHARP's Y-down/Z-forward axes to Y-up/Z-back.
    let sharpToARKit =
        simd_float4x4(
            simd_quatf(
                angle: .pi / 2,
                axis: SIMD3<Float>(0, 0, 1)
            )
        )
        * simd_float4x4(
            simd_quatf(
                angle: .pi,
                axis: SIMD3<Float>(1, 0, 0)
            )
        )
    
    var body: some View {
        let cameraPose = cameraController.pose

        ZStack {
            RealityView { content in
                let resource = GaussianSplatResource(
                    posedSplat.resource
                )
                
                // SHARP outputs activated scale and opacity values. Its color
                // output is linear RGB and is converted to degree-zero SH
                // coefficients while creating the buffer resource.
                resource.scaleActivation = .identity
                resource.opacityActivation = .identity
                resource.projectionMode = .perspective
                resource.sortingMode = .depth
                if let linearSRGB = CGColorSpace(name: CGColorSpace.linearSRGB) {
                    resource.colorSpace = linearSRGB
                }

                let splatEntity = Entity()
                splatEntity.name = "sharp-splat"
                splatEntity.components.set(
                    GaussianSplatComponent(resource)
                )
                splatEntity.transform = Transform(
                    matrix:
                        posedSplat.cameraInfo.cameraTransform
                    * sharpToARKit
                )
                
                content.camera = .virtual
                content.add(cameraController.makeCamera())
                content.add(splatEntity)
            } update: { content in
                if let camera = content.entities.first(
                    where: {
                        $0.name == RealityKitTraverseCameraController.cameraName
                    }
                ) as? PerspectiveCamera {
                    cameraController.apply(cameraPose, to: camera)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(cameraController.orbitGesture)
            .simultaneousGesture(cameraController.zoomGesture)
            .background(.black)

            RealityKitTraverseCameraControls(
                controller: cameraController
            )
        }
        .task {
            await cameraController.runFlightLoop()
        }
    }
}
