//
//  ARInfoView.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/27/26.
//

import SwiftUI
import SharpOnPhoneModels

public struct ARInfoView: View {
    
    let startedRecording: Bool
    let trackingState: String
    let cameraPosition: SIMD3<Float>
    let recordedVideoURL: URL?
    let cameraInfo: [ARCameraInfo]
    let recordedMeshes: [UUID: RecordedMeshAnchor]
    let onRestartBaseLocation: () -> Void
    let onToggleRecording: () -> Void
    
    public init(
        startedRecording: Bool,
        trackingState: String,
        cameraPosition: SIMD3<Float>,
        recordedVideoURL: URL?,
        cameraInfo: [ARCameraInfo],
        recordedMeshes: [UUID: RecordedMeshAnchor],
        onRestartBaseLocation: @escaping () -> Void,
        onToggleRecording: @escaping () -> Void
    ) {
        self.startedRecording = startedRecording
        self.trackingState = trackingState
        self.cameraPosition = cameraPosition
        self.recordedVideoURL = recordedVideoURL
        self.recordedMeshes = recordedMeshes
        self.cameraInfo = cameraInfo
        self.onRestartBaseLocation = onRestartBaseLocation
        self.onToggleRecording = onToggleRecording
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                ARStatsView(
                    trackingState: trackingState,
                    cameraPosition: cameraPosition,
                    onRestartBaseLocation: onRestartBaseLocation,
                )
                RecordButton(
                    startedRecording: startedRecording,
                    onToggleRecording: onToggleRecording
                )
                .padding(.leading)
                
                if let recordedVideoURL {
                    NavigationLink {
                        RecordedVideoURL(
                            url: recordedVideoURL,
                            recordedMeshes: recordedMeshes,
                            cameraInfo: cameraInfo
                        )
                    } label: {
                        VideoDoneView()
                    }
                }
                
                Spacer()
            }
            Spacer()
        }
    }
}

// MARK: - Video Done
struct VideoDoneView: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .contentShape(Rectangle())
            .frame(width: 50, height: 50)
            .glassEffect(.regular, in: .rect(cornerRadius: 25))
    }
}

// MARK: - Record Button
struct RecordButton: View {
    
    let startedRecording: Bool
    let onToggleRecording: () -> Void
    
    var body: some View {
        Button(action: onToggleRecording) {
            Image(
                systemName: startedRecording
                ? "stop.fill"
                : "record.circle.fill"
            )
            .frame(width: 50, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: 25))
    }
}

// MARK: - Stats View
struct ARStatsView: View {
    
    let trackingState: String
    let cameraPosition: SIMD3<Float>
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
            startedRecording: false,
            trackingState: "Normal",
            cameraPosition: .init(
                x: 0,
                y: 0,
                z: 0
            ),
            recordedVideoURL: nil,
            cameraInfo: [],
            recordedMeshes: [:],
            onRestartBaseLocation: {},
            onToggleRecording: {}
        )
    }
}
