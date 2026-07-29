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
    let unloadMemory: () -> Void
    let savedProject: CameraInfoStore.SavedProject
    
    @State private var playerController: ARVideoPlayerController
    
    init(
        onRunSharp: @escaping (UIImage, Double) async throws -> SharpSplatBufferResource,
        unloadMemory: @escaping () -> Void,
        savedProject: CameraInfoStore.SavedProject
    ) {
        self.unloadMemory = unloadMemory
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
    @State private var processAllTask: Task<Void, Never>?
    @State private var processedSplats: [PosedSplat] = []
    @State private var stepForProcess: Int = 1
    
    var body: some View {
        VStack {
            
            ZStack {
                ARVideoPlayer(controller: playerController)
                
                PhoneStatsView()
            }
            
            if !processedSplats.isEmpty {
                HStack {
                    NavigationLink {
                        ZStack {
                            PosedSplatPreview(posedSplats: processedSplats)
                            
                            PhoneStatsView()
                        }
                    } label: {
                        Text("View Guassian Splat Reconstruction")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isProcessing)
                    
                    Text("Splats: \(processedSplats.count)")
                }
            }
            VStack {
                Text("\(playerController.currentFrameIndex)/\(playerController.totalFrameCount)")
                
                Button("Free Memory") {
                    unloadMemory()
                }
                .buttonStyle(.glassProminent)
            }
            
            HStack {
                Button("Process All") {
                    self.processAll()
                }
                .buttonStyle(.glassProminent)
                .disabled(isProcessing)
                
                Button("Process") {
                    self.process()
                }
                .buttonStyle(.glassProminent)
                .disabled(isProcessing)
                
                Button("Step Forward") {
                    self.playerController.stepForward()
                }
                .buttonStyle(.glassProminent)
            }
            
            HStack {
                Button("Cancel Process") {
                    processAllTask?.cancel()
                }
                .buttonStyle(.glassProminent)
                
                Picker("Step Size", selection: $stepForProcess) {
                    ForEach(1...30, id: \.self) { value in
                        Text("\(value)")
                            .tag(value)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.bottom, 4)
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
    }
    
    private func processAll() {
        processAllTask?.cancel()
        processAllTask = Task { @MainActor in
            isProcessing = true
            defer { isProcessing = false }
            
            // Forces frame metadata to load.
            await playerController.seek(
                toFrame: 0,
                pause: true
            )
            
            let frameCount = playerController.totalFrameCount
            
            guard frameCount > 0 else {
                error = "Unable to determine video frame count."
                showError = true
                return
            }
            
            for index in stride(
                from: 0,
                to: frameCount,
                by: stepForProcess
            ) {
                guard !Task.isCancelled else {
                    return
                }
                
                await playerController.seek(
                    toFrame: index,
                    pause: true
                )
                
                let succeeded = await processCurrentFrame()
                
                if !succeeded {
                    return
                }
            }
        }
    }
    
    @MainActor
    private func processCurrentFrame() async -> Bool {
        guard
            let image = await playerController.freezeAndCaptureCurrentFrame(),
            let cameraInfo = playerController.currentCameraInfo
        else {
            error = """
        CurrentCameraInfo Nil: \(playerController.currentCameraInfo == nil), \
        CurrentFrame Nil: \(playerController.currentFrame == nil)
        """
            showError = true
            return false
        }
        
        // Avoid processing another video frame mapped to the same camera sample.
        guard !processedSplats.contains(where: {
            $0.cameraInfo.id == cameraInfo.id
        }) else {
            return true
        }
        
        let focalLength = cameraInfo.intrinsics.columns.1.y
        let disparityFactor =
        Double(focalLength) / Double(image.size.width)
        
        do {
            let resource = try await onRunSharp(
                image,
                disparityFactor
            )
            
            processedSplats.append(
                .init(
                    resource: resource,
                    cameraInfo: cameraInfo
                )
            )
            
            return true
        } catch {
            self.error = error.localizedDescription
            showError = true
            return false
        }
    }
    
    private func process() {
        if isProcessing { return }
        Task { @MainActor in
            isProcessing = true
            defer {
                playerController.unfreeze()
                isProcessing = false
            }
            
            let image = await playerController.freezeAndCaptureCurrentFrame()
            
            if let cameraInfo = playerController.currentCameraInfo,
               let image {
                // The video's 90° preferred transform maps the camera's vertical
                // focal length (fy) onto the displayed image's horizontal axis.
                let focalLength = cameraInfo.intrinsics.columns.1.y
                let disparityFactor =
                    Double(focalLength) / Double(image.size.width)
                do {
                    let resource = try await onRunSharp(image, disparityFactor)
                    
                    // remove processedSplat if duplicate found
                    processedSplats.removeAll(where: { $0.cameraInfo.id == cameraInfo.id })
                    processedSplats.append(
                        .init(
                            resource: resource,
                            cameraInfo: cameraInfo
                        )
                    )
                    
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
    
    let posedSplats: [PosedSplat]
    @State private var cameraController: RealityKitTraverseCameraController

    init(posedSplats: [PosedSplat]) {
        self.posedSplats = posedSplats
        
        _cameraController = State(
            initialValue: RealityKitTraverseCameraController(
                cameraInfo: posedSplats.map(\.cameraInfo)
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
                for (index, splat) in posedSplats.enumerated() {
                    let resource = GaussianSplatResource(splat.resource)
                    
                    resource.scaleActivation = .identity
                    resource.opacityActivation = .identity
                    resource.projectionMode = .perspective
                    resource.sortingMode = .depth
                    
                    if let linearSRGB = CGColorSpace(
                        name: CGColorSpace.linearSRGB
                    ) {
                        resource.colorSpace = linearSRGB
                    }
                    
                    let entity = Entity()
                    entity.name = "sharp-splat-\(index)"
                    entity.components.set(
                        GaussianSplatComponent(resource)
                    )
                    entity.transform = Transform(
                        matrix:
                            splat.cameraInfo.cameraTransform
                        * sharpToARKit
                    )
                    
                    content.add(entity)
                }
                content.add(cameraController.makeCamera())
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
