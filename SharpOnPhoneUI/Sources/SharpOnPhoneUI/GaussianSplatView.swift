//
//  GaussianSplatView.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/26/26.
//

import RealityKit
import SwiftUI

struct GaussianSplatView: View {
    let gaussianSplatBufferResource: SharpSplatBufferResource

    @State private var cameraPosition = SIMD3<Float>.zero
    @State private var cameraOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    @State private var movementInput = SIMD2<Float>.zero
    @State private var lookInput = SIMD2<Float>.zero
    @State private var verticalInput: Float = 0
    @State private var movementSpeed: Float = 1.5
    @State private var previousLookTranslation = CGSize.zero
    @State private var previousMagnification: CGFloat = 1

    private let presentationScale: Float = 0.52

    var body: some View {
#if targetEnvironment(simulator)
        ContentUnavailableView(
            "Gaussian Splat Preview Unavailable",
            systemImage: "move.3d",
            description: Text("RealityKit renders Gaussian splats on a physical device.")
        )
        .navigationTitle("Fly")
#else
        ZStack {
            RealityView { content in
                let resource = GaussianSplatResource(
                    gaussianSplatBufferResource
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

                content.camera = .virtual
                content.add(splatEntity)
            } update: { content in
                guard let splatEntity = content.entities.first(
                    where: { $0.name == "sharp-splat" }
                ) else {
                    return
                }

                // RealityView doesn't expose its virtual camera transform.
                // Applying the inverse camera rig to the scene produces the
                // same view while retaining RealityKit's splat renderer.
                let camera = Transform(
                    scale: .one,
                    rotation: cameraRotation,
                    translation: cameraPosition
                )
                let presentation = Transform(
                    scale: SIMD3<Float>(repeating: presentationScale),
                    rotation: simd_quatf(
                        angle: .pi,
                        axis: SIMD3<Float>(1, 0, 0)
                    )
                )
                splatEntity.transform = Transform(
                    matrix: simd_inverse(camera.matrix) * presentation.matrix
                )
            }
            .contentShape(Rectangle())
            .simultaneousGesture(directLookGesture)
            .simultaneousGesture(dollyGesture)
            .ignoresSafeArea()

            flightControls
        }
        .navigationTitle("Fly")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await runFlightLoop()
        }
#endif
    }

    private var flightControls: some View {
        VStack {
            HStack(spacing: 10) {
                Button {
                    cycleSpeed()
                } label: {
                    Label(
                        "\(movementSpeed.formatted(.number.precision(.fractionLength(1))))×",
                        systemImage: "speedometer"
                    )
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Movement speed")
                .accessibilityValue("\(movementSpeed) times")

                Spacer()

                Button {
                    resetView()
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
                    input: $movementInput,
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
                    input: $lookInput,
                    symbol: "scope",
                    accessibilityName: "Look"
                )
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }

    private var cameraRotation: simd_quatf { cameraOrientation }

    private var directLookGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let deltaX = value.translation.width
                    - previousLookTranslation.width
                let deltaY = value.translation.height
                    - previousLookTranslation.height

                rotateCamera(
                    horizontal: -Float(deltaX) * 0.005,
                    vertical: -Float(deltaY) * 0.005
                )
                previousLookTranslation = value.translation
            }
            .onEnded { _ in
                previousLookTranslation = .zero
            }
    }

    private var dollyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / previousMagnification
                let forward = cameraRotation.act(
                    SIMD3<Float>(0, 0, -1)
                )
                cameraPosition += forward * Float(delta - 1) * 1.6
                previousMagnification = value
            }
            .onEnded { _ in
                previousMagnification = 1
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
                verticalInput = isPressing ? direction : 0
            },
            perform: {}
        )
        .accessibilityLabel(label)
    }

    @MainActor
    private func runFlightLoop() async {
        while !Task.isCancelled {
            advanceFlight(by: 1 / 60)
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    private func advanceFlight(by deltaTime: Float) {
        rotateCamera(
            horizontal: -lookInput.x * 1.8 * deltaTime,
            vertical: -lookInput.y * 1.45 * deltaTime
        )

        let rotation = cameraRotation
        let right = rotation.act(SIMD3<Float>(1, 0, 0))
        let forward = rotation.act(SIMD3<Float>(0, 0, -1))
        let up = SIMD3<Float>(0, 1, 0)
        let direction = right * movementInput.x
            + forward * -movementInput.y
            + up * verticalInput

        if simd_length_squared(direction) > 0.0001 {
            cameraPosition += simd_normalize(direction)
                * movementSpeed
                * deltaTime
        }
    }

    private func rotateCamera(horizontal: Float, vertical: Float) {
        guard horizontal != 0 || vertical != 0 else { return }

        // Rotate around the camera's own up and right axes. Quaternion
        // accumulation avoids the Euler pitch limit and lets the camera pass
        // smoothly over the poles and underneath the splat.
        let localUp = cameraOrientation.act(SIMD3<Float>(0, 1, 0))
        let localRight = cameraOrientation.act(SIMD3<Float>(1, 0, 0))
        let horizontalRotation = simd_quatf(
            angle: horizontal,
            axis: localUp
        )
        let verticalRotation = simd_quatf(
            angle: vertical,
            axis: localRight
        )
        cameraOrientation = simd_normalize(
            verticalRotation * horizontalRotation * cameraOrientation
        )
    }

    private func cycleSpeed() {
        switch movementSpeed {
        case ..<1:
            movementSpeed = 1.5
        case ..<2:
            movementSpeed = 4
        default:
            movementSpeed = 0.5
        }
    }

    private func resetView() {
        cameraPosition = .zero
        cameraOrientation = simd_quatf(
            angle: 0,
            axis: SIMD3<Float>(0, 1, 0)
        )
        movementInput = .zero
        lookInput = .zero
        verticalInput = 0
        previousLookTranslation = .zero
        previousMagnification = 1
    }
}
