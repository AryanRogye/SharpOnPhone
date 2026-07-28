//
//  ARInfoView.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/27/26.
//

import SwiftUI

public struct ARInfoView: View {
    
    let trackingState: String
    let cameraPosition: SIMD3<Float>
    let latestFrame: ARCameraFrame?
    let onCaptureCurrentFrame: () -> Void
    let onRestartBaseLocation: () -> Void
    
    public init(
        trackingState: String,
        cameraPosition: SIMD3<Float>,
        latestFrame: ARCameraFrame?,
        onCaptureCurrentFrame: @escaping () -> Void,
        onRestartBaseLocation: @escaping () -> Void
    ) {
        self.trackingState = trackingState
        self.cameraPosition = cameraPosition
        self.latestFrame = latestFrame
        self.onCaptureCurrentFrame = onCaptureCurrentFrame
        self.onRestartBaseLocation = onRestartBaseLocation
    }
    
    @State private var showState: Bool = false
    
    public var body: some View {
        VStack(spacing: 16) {
            ARStatsView(
                trackingState: trackingState,
                cameraPosition: cameraPosition,
                latestFrame: latestFrame,
                onCaptureCurrentFrame: onCaptureCurrentFrame,
                onRestartBaseLocation: onRestartBaseLocation,
            )
            Spacer()
        }
    }
}

struct ARStatsView: View {
    
    let trackingState: String
    let cameraPosition: SIMD3<Float>
    let latestFrame: ARCameraFrame?
    let onCaptureCurrentFrame: () -> Void
    let onRestartBaseLocation: () -> Void

    @State private var showState = false
    
    var body: some View {
        GlassEffectContainer {
            VStack {
                HStack(spacing: 10) {
                    
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(width: 20)
                    
                    Text("Tracking: \(trackingState)")
                        .font(.headline)
                        .lineLimit(1)
                        .opacity(showState ? 1 : 0)
                        .blur(radius: showState ? 0 : 8)
                        .frame(
                            maxWidth: showState ? .infinity : 0,
                            alignment: .leading
                        )
                        .clipped()
                    
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            showState = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.bold)
                    }
                    .buttonStyle(.plain)
                    .opacity(showState ? 1 : 0)
                    .blur(radius: showState ? 0 : 6)
                    .scaleEffect(showState ? 1 : 0.75)
                    .frame(width: showState ? 24 : 0)
                    .clipped()
                    .allowsHitTesting(showState)
                }
                
                if showState {
                    Text("(\(cameraPosition.x), \(cameraPosition.y), \(cameraPosition.z))")
                        .monospacedDigit()
                        .opacity(showState ? 1 : 0)
                        .blur(radius: showState ? 0 : 6)
                        .scaleEffect(showState ? 1 : 0.75)
                        .clipped()
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                    
                    HStack {
                        Button("Capture Frame") {
                            onCaptureCurrentFrame()
                        }
                        .buttonStyle(.glassProminent)
                        
                        if let frame = latestFrame {
                            Text("Captured at \(frame.timestamp)")
                        }
                        
                        Spacer()
                    }
                    HStack {
                        Button("Restart Base Location") {
                            onRestartBaseLocation()
                        }
                        .buttonStyle(.glassProminent)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, showState ? 16 : 15)
            .padding(.vertical, showState ? 16 : 0)
            .frame(
                maxWidth: showState ? .infinity : 50,
                alignment: .leading
            )
            .frame(
                height: showState ? nil : 50,
                alignment: showState ? .top : .center
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard !showState else {
                    return
                }
                
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    showState = true
                }
            }
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(
                    cornerRadius: showState ? 12 : 25
                )
            )
            .padding(.horizontal)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.78),
                value: showState
            )
        }
    }
}


#Preview {
    
    ZStack {
        LinearGradient(
            colors: [.black, .gray],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        ARInfoView(
            trackingState: "Normal",
            cameraPosition: .init(
                x: 0,
                y: 0,
                z: 0
            ),
            latestFrame: nil,
            onCaptureCurrentFrame: {},
            onRestartBaseLocation: {}
        )
    }
}
