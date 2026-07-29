//
//  RecordedVideoURL.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/27/26.
//

import AVKit
import SwiftUI
import SharpOnPhoneModels

struct RecordedVideoView: View {
    
    let cameraInfo: [ARCameraInfo]
    let recordedMeshes: [UUID: RecordedMeshAnchor]
    let onSave: (String) -> Void
    
    @State private var player: AVPlayer
    @State private var currentCameraInfo: ARCameraInfo?
    @State private var timeObserver: Any?
    @State private var showSaveRecording: Bool = false
    
    init(
        url: URL,
        recordedMeshes: [UUID: RecordedMeshAnchor],
        cameraInfo: [ARCameraInfo],
        onSave: @escaping (String) -> Void
    ) {
        self.onSave = onSave
        self.cameraInfo = cameraInfo.sorted {
            $0.timestamp < $1.timestamp
        }
        self.recordedMeshes = recordedMeshes
        
        _player = State(
            initialValue: AVPlayer(url: url)
        )
    }
    
    var body: some View {
        VStack {
            VideoPlayer(player: player)
            
            if let currentCameraInfo {
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
                        RealityKitTraverseARCameraInfoView(
                            cameraInfo: cameraInfo,
                            recordedMeshes: recordedMeshes
                        )
                    } label: {
                        Text("View Path Taken In 3D")
                    }
                    .buttonStyle(.glassProminent)

                    Button {
                        showSaveRecording = true
                    } label: {
                        Text("Save Recording")
                    }
                    .buttonStyle(.glassProminent)
                }
                .monospacedDigit()
            }
        }
        .onAppear {
            beginObservingPlayback()
            player.play()
        }
        .onDisappear {
            stopObservingPlayback()
            player.pause()
        }
        .sheet(isPresented: $showSaveRecording) {
            SaveRecordingView { name in
                onSave(name)
                showSaveRecording = false
            }
        }
    }
    
    private func beginObservingPlayback() {
        guard timeObserver == nil else {
            return
        }
        
        let interval = CMTime(
            seconds: 1.0 / 30.0,
            preferredTimescale: 600
        )
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { time in
            guard time.seconds.isFinite else {
                return
            }
            
            Task { @MainActor in
                currentCameraInfo = closestCameraInfo(
                    to: time.seconds
                )
            }
        }
    }
    
    private func stopObservingPlayback() {
        guard let timeObserver else {
            return
        }
        
        player.removeTimeObserver(timeObserver)
        self.timeObserver = nil
    }
    
    private func closestCameraInfo(
        to playbackTime: TimeInterval
    ) -> ARCameraInfo? {
        guard !cameraInfo.isEmpty else {
            return nil
        }
        
        var lowerBound = 0
        var upperBound = cameraInfo.count
        
        while lowerBound < upperBound {
            let middleIndex = lowerBound + (upperBound - lowerBound) / 2
            
            if cameraInfo[middleIndex].timestamp < playbackTime {
                lowerBound = middleIndex + 1
            } else {
                upperBound = middleIndex
            }
        }
        
        if lowerBound == 0 {
            return cameraInfo[0]
        }
        
        if lowerBound == cameraInfo.count {
            return cameraInfo[cameraInfo.count - 1]
        }
        
        let previous = cameraInfo[lowerBound - 1]
        let next = cameraInfo[lowerBound]
        
        let previousDistance = abs(
            previous.timestamp - playbackTime
        )
        
        let nextDistance = abs(
            next.timestamp - playbackTime
        )
        
        return previousDistance <= nextDistance
        ? previous
        : next
    }
}

private struct SaveRecordingView: View {

    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Recording name", text: $name)
            }
            .navigationTitle("Save Recording")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}
