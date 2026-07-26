//
//  GaussianSplatView.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/26/26.
//

import RealityKit
import SwiftUI

struct GaussianSplatView: View {
    let gaussianSplatBufferResource: GaussianSplatResource.BufferResource

    @State private var yaw: Float = 0
    @State private var pitch: Float = 0
    @State private var sceneScale: Float = 0.68
    @State private var sceneOffset = SIMD3<Float>.zero
    @State private var previousLookTranslation = CGSize.zero
    @State private var previousMagnification: CGFloat = 1
    @State private var previousJoystickTranslation = CGSize.zero
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RealityView { content in
                let resource = GaussianSplatResource(
                    gaussianSplatBufferResource
                )

                // SHARP has already applied these activations. Its colors are
                // linear RGB, so describe them that way instead of relying on
                // RealityKit's beta defaults.
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

                let yawRotation = simd_quatf(
                    angle: yaw,
                    axis: SIMD3<Float>(0, 1, 0)
                )
                let pitchRotation = simd_quatf(
                    angle: pitch,
                    axis: SIMD3<Float>(1, 0, 0)
                )

                splatEntity.transform.rotation = yawRotation * pitchRotation
                splatEntity.transform.translation = sceneOffset
                splatEntity.transform.scale = SIMD3<Float>(
                    repeating: sceneScale
                )
            }
            .contentShape(Rectangle())
            .simultaneousGesture(lookGesture)
            .simultaneousGesture(zoomGesture)
            .ignoresSafeArea()

            movementJoystick
                .padding(.leading, 22)
                .padding(.bottom, 28)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        resetView()
                    } label: {
                        Image(systemName: "viewfinder")
                            .font(.title3.weight(.semibold))
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Reset view")
                }
                .padding(.trailing, 22)
                .padding(.bottom, 34)
            }
        }
        .navigationTitle("Gaussian Splat")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var lookGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let deltaX = value.translation.width
                    - previousLookTranslation.width
                let deltaY = value.translation.height
                    - previousLookTranslation.height

                yaw += Float(deltaX) * 0.006
                pitch = min(
                    .pi / 2,
                    max(-.pi / 2, pitch + Float(deltaY) * 0.006)
                )
                previousLookTranslation = value.translation
            }
            .onEnded { _ in
                previousLookTranslation = .zero
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / previousMagnification
                sceneScale = min(
                    2.5,
                    max(0.12, sceneScale * Float(delta))
                )
                previousMagnification = value
            }
            .onEnded { _ in
                previousMagnification = 1
            }
    }

    private var movementJoystick: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2

            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    }

                Image(systemName: "circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.white.opacity(0.9))
                    .offset(
                        x: joystickKnobOffset(in: radius).width,
                        y: joystickKnobOffset(in: radius).height
                    )
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let translation = clampedJoystickTranslation(
                            value.translation,
                            radius: radius
                        )
                        let deltaX = translation.width
                            - previousJoystickTranslation.width
                        let deltaY = translation.height
                            - previousJoystickTranslation.height

                        sceneOffset.x += Float(deltaX) * 0.008
                        sceneOffset.z += Float(deltaY) * 0.012
                        previousJoystickTranslation = translation
                    }
                    .onEnded { _ in
                        previousJoystickTranslation = .zero
                    }
            )
            .accessibilityLabel("Move camera")
            .accessibilityHint(
                "Drag left or right to strafe. Drag up or down to move forward or backward."
            )
        }
        .frame(width: 112, height: 112)
    }

    private func joystickKnobOffset(in radius: CGFloat) -> CGSize {
        clampedJoystickTranslation(
            previousJoystickTranslation,
            radius: radius
        )
    }

    private func clampedJoystickTranslation(
        _ translation: CGSize,
        radius: CGFloat
    ) -> CGSize {
        let knobRadius: CGFloat = 21
        let limit = max(0, radius - knobRadius - 8)
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

    private func resetView() {
        yaw = 0
        pitch = 0
        sceneScale = 0.68
        sceneOffset = .zero
        previousLookTranslation = .zero
        previousMagnification = 1
        previousJoystickTranslation = .zero
    }
}
