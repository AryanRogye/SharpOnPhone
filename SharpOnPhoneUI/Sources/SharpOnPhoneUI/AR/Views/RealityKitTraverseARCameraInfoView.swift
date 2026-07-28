//
//  RealityKitTraverseARCameraInfoView.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/27/26.
//

import SwiftUI
import RealityKit
import SharpOnPhoneModels

//private func \sqrt{(x_2 - x_1)^2 + (y_2 - y_1)^2 + (z_2 - z_1)^2}

struct RealityKitTraverseARCameraInfoView: View {
    
    let cameraInfo: [ARCameraInfo]
    let recordedMeshes: [UUID: RecordedMeshAnchor]
    @State private var playbackTime: TimeInterval = 0
    @State private var cameraController: RealityKitTraverseCameraController
    @State private var timer: Timer?

    init(
        cameraInfo: [ARCameraInfo],
        recordedMeshes: [UUID: RecordedMeshAnchor] = [:]
    ) {
        self.cameraInfo = cameraInfo
        self.recordedMeshes = recordedMeshes
        _cameraController = State(
            initialValue: RealityKitTraverseCameraController(
                cameraInfo: cameraInfo,
                recordedMeshes: recordedMeshes
            )
        )
    }
    
    var maxTimeInterval: TimeInterval? {
        cameraInfo.last?.timestamp
    }
    
    var revealed: [ARCameraInfo] {
        Array(
            cameraInfo.prefix {
                $0.timestamp <= playbackTime
            }
        )
    }

    var body: some View {
        if let maxTimeInterval, let firstPoint = cameraInfo.first {
            let cameraPose = cameraController.pose

            ZStack {
                RealityView { content in
                    
                    let startPos: SIMD3<Float> = [
                        firstPoint.cameraTransform.xPos,
                        firstPoint.cameraTransform.yPos,
                        firstPoint.cameraTransform.zPos
                    ]
                    
                    // this is the starting sphere
                    let sphere = ModelEntity(
                        mesh: .generateSphere(radius: 0.01),
                        materials: [SimpleMaterial(color: .yellow, isMetallic: false)]
                    )
                    sphere.name = "Sphere"
                    sphere.position = startPos
                    content.add(sphere)
                    
                    // this is the camera
                    content.add(cameraController.makeCamera())
                    
                    let root = Entity()
                    root.name = "Trail"
                    content.add(root)

                    content.add(
                        RealityKitRecordedMeshRenderer.makeRoot(
                            from: recordedMeshes
                        )
                    )
                } update: { content in

                    if let camera = content.entities.first(
                        where: {
                            $0.name == RealityKitTraverseCameraController.cameraName
                        }
                    ) as? PerspectiveCamera {
                        cameraController.apply(cameraPose, to: camera)
                    }
                    
                    // upate the path (dont change this codex)
                    if let trail = content.entities.first(where: { $0.name == "Trail" }) {
                        let desiredSegmentCount = max(revealed.count - 1, 0)
                        let existingSegmentCount = trail.children.count
                        print("Desired Segment Count: \(desiredSegmentCount)")
                        print("Existing Segment Count: \(existingSegmentCount)")
                        
                        if desiredSegmentCount > existingSegmentCount {
                            for i in existingSegmentCount..<desiredSegmentCount {
                                // create segment from i to point i+1
                                let from = revealed[i]
                                let to = revealed[i + 1]
                                
                                // Create and add the segment here.
                                let fromPos = SIMD3<Float>(from.cameraTransform.xPos, from.cameraTransform.yPos, from.cameraTransform.zPos)
                                let toPos = SIMD3<Float>(to.cameraTransform.xPos, to.cameraTransform.yPos, to.cameraTransform.zPos)
                                
                                let length = from.cameraTransform.distance(to: to.cameraTransform)
                                let mid = from.cameraTransform.midpoint(to: to.cameraTransform)
                                
                                let segment = ModelEntity(
                                    mesh: .generateBox(size: [length, 0.005, 0.005]),
                                    materials: [SimpleMaterial(color: .yellow, isMetallic: false)]
                                )
                                segment.name = "segment_\(i)"
                                segment.position = mid
                                
                                // rotate from box's default "long axis" (X) to point toward (toPos - fromPos)
                                let direction = normalize(toPos - fromPos)
                                let defaultAxis = SIMD3<Float>(1, 0, 0)
                                segment.orientation = simd_quatf(from: defaultAxis, to: direction)
                                
                                trail.addChild(segment)
                            }
                        }
                        if desiredSegmentCount < existingSegmentCount {
                            // we have looped so we have to restart it
                            for entity in Array(trail.children) {
                                entity.removeFromParent()
                            }
                        }
                    }
                    
                }
                .contentShape(Rectangle())
                .simultaneousGesture(cameraController.orbitGesture)
                .simultaneousGesture(cameraController.zoomGesture)
                .background(.black)
                .task {
                    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                        Task { @MainActor in
                            playbackTime += 0.01
                            if playbackTime > maxTimeInterval {
                                playbackTime = 0
                            }
                        }
                    }
                }
                .onDisappear {
                    timer?.invalidate()
                }
                
                RealityKitTraverseInfo(playbackTime: playbackTime, maxTimeInterval: maxTimeInterval)
                RealityKitTraverseCameraControls(
                    controller: cameraController
                )
            }
            .task {
                await cameraController.runFlightLoop()
            }
        } else {
            Text("No Valid Max Time Interval")
        }
    }

}

private struct RealityKitTraverseInfo: View {
    
    let playbackTime: TimeInterval
    let maxTimeInterval: TimeInterval
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .leading) {
                    Text("Current: \(playbackTime)")
                    Text("Max: \(maxTimeInterval)")
                }
            }
            .padding(.horizontal)
        }
        .foregroundStyle(.white)
    }
}

#Preview {
    RealityKitTraverseARCameraInfoView(
        cameraInfo: ARCameraInfo.mock,
    )
}
