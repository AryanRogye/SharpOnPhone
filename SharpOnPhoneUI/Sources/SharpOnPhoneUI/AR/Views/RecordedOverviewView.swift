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
    
    let savedProject: CameraInfoStore.SavedProject
    
    var cameraInfo: [ARCameraInfo] {
        savedProject.cameraInfo.sorted {
            $0.timestamp < $1.timestamp
        }
    }
    
    @State private var player: AVPlayer
    @State private var currentCameraInfo: ARCameraInfo?
    @State private var timeObserver: Any?
    @State private var showSaveRecording: Bool = false
    
    public init(
        savedProject: CameraInfoStore.SavedProject,
    ) {
        self.savedProject = savedProject
        
        _player = State(
            initialValue: AVPlayer(url: savedProject.videoURL)
        )
    }
    
    public var body: some View {
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
                        GaussianSplatRecontructionView(savedProject: savedProject)
                    } label: {
                        Text("View Gaussian Splat")
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
