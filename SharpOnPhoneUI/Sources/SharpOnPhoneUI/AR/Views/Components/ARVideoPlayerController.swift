//
//  ARVideoPlayerController.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/28/26.
//


import AVFoundation
import Observation
import SharpOnPhoneModels

@Observable
@MainActor
public final class ARVideoPlayerController {
    
    let player: AVPlayer
    
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var duration: TimeInterval = 0
    public private(set) var isPlaying = false
    public private(set) var currentCameraInfo: ARCameraInfo?
    
    private let cameraInfo: [ARCameraInfo]
    private var timeObserver: Any?
    
    public init(
        url: URL,
        cameraInfo: [ARCameraInfo]
    ) {
        self.player = AVPlayer(url: url)
        self.cameraInfo = cameraInfo.sorted {
            $0.timestamp < $1.timestamp
        }
    }
    
    func startObserving() {
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
        ) { [weak self] time in
            guard let self else {
                return
            }
            
            guard time.seconds.isFinite else {
                return
            }
            
            currentTime = time.seconds
            currentCameraInfo = closestCameraInfo(
                to: time.seconds
            )
            
            updateDuration()
        }
    }
    
    func stopObserving() {
        guard let timeObserver else {
            return
        }
        
        player.removeTimeObserver(timeObserver)
        self.timeObserver = nil
    }
    
    public func play() {
        player.play()
        isPlaying = true
    }
    
    public func pause() {
        player.pause()
        isPlaying = false
    }
    
    public func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func seek(to seconds: TimeInterval) {
        seek(to: seconds, pause: false)
    }
    
    /// Pauses playback and seeks to an exact time, keeping the video on that frame.
    public func seekAndPause(at seconds: TimeInterval) {
        seek(to: seconds, pause: true)
    }
    
    private func seek(
        to seconds: TimeInterval,
        pause shouldPause: Bool
    ) {
        if shouldPause {
            pause()
        }
        
        let requestedTime = max(seconds, 0)
        let knownDuration = player.currentItem?.duration.seconds
        let clampedTime: TimeInterval
        
        if let knownDuration, knownDuration.isFinite {
            duration = knownDuration
            clampedTime = min(requestedTime, knownDuration)
        } else {
            clampedTime = requestedTime
        }
        
        let time = CMTime(
            seconds: clampedTime,
            preferredTimescale: 600
        )
        
        player.seek(
            to: time,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        
        currentTime = clampedTime
        currentCameraInfo = closestCameraInfo(
            to: clampedTime
        )
    }
    
    private func updateDuration() {
        guard let seconds = player.currentItem?.duration.seconds else {
            return
        }
        
        guard seconds.isFinite else {
            return
        }
        
        duration = seconds
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
            let middleIndex =
                lowerBound + (upperBound - lowerBound) / 2
            
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
