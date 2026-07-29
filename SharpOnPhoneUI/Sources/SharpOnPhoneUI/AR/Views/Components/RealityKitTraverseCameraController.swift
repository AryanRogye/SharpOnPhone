//
//  RealityKitTraverseCameraController.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/27/26.
//

import Observation
import RealityKit
import SwiftUI
import SharpOnPhoneModels

@MainActor
@Observable
final class RealityKitTraverseCameraController {
    static let cameraName = "OrbitCamera"

    struct Pose {
        let position: SIMD3<Float>
        let target: SIMD3<Float>
    }

    var orbitYaw: Float = 0
    var orbitPitch: Float = 0.35
    var orbitDistanceScale: Float = 1
    var movementInput = SIMD2<Float>.zero
    var lookInput = SIMD2<Float>.zero
    var verticalInput: Float = 0
    var movementSpeed: Float = 1.5

    private let initialCenter: SIMD3<Float>
    private let initialDistance: Float
    private var centerOffset = SIMD3<Float>.zero
    private var previousOrbitTranslation = CGSize.zero
    private var previousMagnification: CGFloat = 1

    init(
        cameraInfo: [ARCameraInfo],
        recordedMeshes: [UUID: RecordedMeshAnchor] = [:]
    ) {
        guard let firstPosition = Self.firstPosition(
            cameraInfo: cameraInfo,
            recordedMeshes: recordedMeshes
        ) else {
            initialCenter = .zero
            initialDistance = 2
            return
        }

        var minimum = firstPosition
        var maximum = firstPosition

        for camera in cameraInfo {
            let position = SIMD3<Float>(
                camera.cameraTransform.xPos,
                camera.cameraTransform.yPos,
                camera.cameraTransform.zPos
            )
            minimum = simd_min(minimum, position)
            maximum = simd_max(maximum, position)
        }

        for anchor in recordedMeshes.values {
            for vertex in anchor.vertices {
                let worldVertex = anchor.transform
                    * SIMD4<Float>(vertex, 1)
                let position = SIMD3<Float>(
                    worldVertex.x,
                    worldVertex.y,
                    worldVertex.z
                )
                minimum = simd_min(minimum, position)
                maximum = simd_max(maximum, position)
            }
        }

        initialCenter = (minimum + maximum) / 2
        initialDistance = max(simd_length(maximum - minimum) * 1.25, 1.5)
    }

    var pose: Pose {
        let distance = initialDistance * orbitDistanceScale
        let horizontalDistance = cos(orbitPitch) * distance
        let target = initialCenter + centerOffset
        let position = target + SIMD3<Float>(
            sin(orbitYaw) * horizontalDistance,
            sin(orbitPitch) * distance,
            cos(orbitYaw) * horizontalDistance
        )
        return Pose(position: position, target: target)
    }

    func makeCamera() -> PerspectiveCamera {
        let camera = PerspectiveCamera()
        camera.name = Self.cameraName
        return camera
    }

    func apply(_ pose: Pose, to camera: PerspectiveCamera) {
        camera.look(
            at: pose.target,
            from: pose.position,
            relativeTo: nil
        )
    }

    var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let deltaX = value.translation.width
                    - self.previousOrbitTranslation.width
                let deltaY = value.translation.height
                    - self.previousOrbitTranslation.height

                self.orbitYaw -= Float(deltaX) * 0.005
                self.orbitPitch += Float(deltaY) * 0.005
                self.clampPitch()
                self.previousOrbitTranslation = value.translation
            }
            .onEnded { _ in
                self.previousOrbitTranslation = .zero
            }
    }

    var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / self.previousMagnification
                self.orbitDistanceScale /= Float(delta)
                self.orbitDistanceScale = min(
                    max(self.orbitDistanceScale, 0.2),
                    5
                )
                self.previousMagnification = value
            }
            .onEnded { _ in
                self.previousMagnification = 1
            }
    }

    func setVerticalInput(_ direction: Float, isActive: Bool) {
        verticalInput = isActive ? direction : 0
    }

    func cycleSpeed() {
        switch movementSpeed {
        case ..<1:
            movementSpeed = 1.5
        case ..<2:
            movementSpeed = 4
        default:
            movementSpeed = 0.5
        }
    }

    func reset() {
        orbitYaw = 0
        orbitPitch = 0.35
        orbitDistanceScale = 1
        centerOffset = .zero
        movementInput = .zero
        lookInput = .zero
        verticalInput = 0
        previousOrbitTranslation = .zero
        previousMagnification = 1
    }

    func runFlightLoop() async {
        while !Task.isCancelled {
            advanceFlight(by: 1 / 60)
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    private func advanceFlight(by deltaTime: Float) {
        orbitYaw -= lookInput.x * 1.8 * deltaTime
        orbitPitch += lookInput.y * 1.45 * deltaTime
        clampPitch()

        let horizontalDistance = cos(orbitPitch)
        let forward = SIMD3<Float>(
            -sin(orbitYaw) * horizontalDistance,
            -sin(orbitPitch),
            -cos(orbitYaw) * horizontalDistance
        )
        let right = SIMD3<Float>(
            cos(orbitYaw),
            0,
            -sin(orbitYaw)
        )
        let up = SIMD3<Float>(0, 1, 0)
        let direction = right * movementInput.x
            + forward * -movementInput.y
            + up * verticalInput

        if simd_length_squared(direction) > 0.0001 {
            centerOffset += simd_normalize(direction)
                * movementSpeed
                * deltaTime
        }
    }

    private func clampPitch() {
        orbitPitch = min(
            max(orbitPitch, -.pi / 2 + 0.05),
            .pi / 2 - 0.05
        )
    }

    private static func firstPosition(
        cameraInfo: [ARCameraInfo],
        recordedMeshes: [UUID: RecordedMeshAnchor]
    ) -> SIMD3<Float>? {
        if let first = cameraInfo.first {
            return SIMD3<Float>(
                first.cameraTransform.xPos,
                first.cameraTransform.yPos,
                first.cameraTransform.zPos
            )
        }

        guard
            let anchor = recordedMeshes.values.first,
            let vertex = anchor.vertices.first
        else {
            return nil
        }

        let worldVertex = anchor.transform * SIMD4<Float>(vertex, 1)
        return SIMD3<Float>(
            worldVertex.x,
            worldVertex.y,
            worldVertex.z
        )
    }
}

struct RealityKitTraverseCameraControls: View {
    @Bindable var controller: RealityKitTraverseCameraController

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Button {
                    controller.cycleSpeed()
                } label: {
                    Label(
                        "\(controller.movementSpeed.formatted(.number.precision(.fractionLength(1))))×",
                        systemImage: "speedometer"
                    )
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Movement speed")
                .accessibilityValue("\(controller.movementSpeed) times")

                Spacer()

                Button {
                    controller.reset()
                } label: {
                    Image(systemName: "viewfinder")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Reset view")
            }
            .padding(.horizontal, 18)

            Spacer()

            HStack(alignment: .bottom, spacing: 16) {
                FlightStick(
                    input: $controller.movementInput,
                    symbol: "move.3d",
                    accessibilityName: "Move"
                )

                VStack(spacing: 10) {
                    altitudeButton(
                        symbol: "chevron.up",
                        direction: 1,
                        label: "Move up"
                    )
                    altitudeButton(
                        symbol: "chevron.down",
                        direction: -1,
                        label: "Move down"
                    )
                }

                Spacer(minLength: 8)

                FlightStick(
                    input: $controller.lookInput,
                    symbol: "scope",
                    accessibilityName: "Look"
                )
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }

    private func altitudeButton(
        symbol: String,
        direction: Float,
        label: String
    ) -> some View {
        Button(action: {}) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.glass)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: 60,
            pressing: { isPressing in
                controller.setVerticalInput(
                    direction,
                    isActive: isPressing
                )
            },
            perform: {}
        )
        .accessibilityLabel(label)
    }
}

struct FlightStick: View {
    @Binding var input: SIMD2<Float>

    let symbol: String
    let accessibilityName: String

    @State private var knobOffset = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2
            let travel = radius - 27

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.22), lineWidth: 1)
                    }

                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                    .offset(knobOffset)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let offset = clamped(
                            value.translation,
                            limit: travel
                        )
                        knobOffset = offset
                        input = SIMD2<Float>(
                            Float(offset.width / travel),
                            Float(offset.height / travel)
                        )
                    }
                    .onEnded { _ in
                        input = .zero
                        withAnimation(.spring(duration: 0.24, bounce: 0.28)) {
                            knobOffset = .zero
                        }
                    }
            )
        }
        .frame(width: 126, height: 126)
        .accessibilityElement()
        .accessibilityLabel(accessibilityName)
    }

    private func clamped(
        _ translation: CGSize,
        limit: CGFloat
    ) -> CGSize {
        let length = hypot(translation.width, translation.height)
        guard length > limit, length > 0 else {
            return translation
        }

        let scale = limit / length
        return CGSize(
            width: translation.width * scale,
            height: translation.height * scale
        )
    }
}
