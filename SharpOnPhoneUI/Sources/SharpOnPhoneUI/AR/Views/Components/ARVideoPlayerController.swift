//
//  ARVideoPlayerController.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/28/26.
//


import AVFoundation
import Observation
import SharpOnPhoneModels
import UIKit

@Observable
@MainActor
public final class ARVideoPlayerController {
    
    let player: AVPlayer
    
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var duration: TimeInterval = 0
    public private(set) var isPlaying = false
    public private(set) var isFrozen = false
    public private(set) var isCapturingFrame = false
    public private(set) var currentFrame: UIImage?
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
            
            if isFrozen, player.rate != 0 {
                player.pause()
                isPlaying = false
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
        guard !isFrozen else {
            return
        }
        
        currentFrame = nil
        player.play()
        isPlaying = true
    }
    
    public func pause() {
        guard !isFrozen else {
            return
        }
        
        player.pause()
        isPlaying = false
    }
    
    public func togglePlayback() {
        guard !isFrozen else {
            return
        }
        
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    /// Pauses on the current frame and prevents playback controls from changing
    /// the play/pause state until `unfreeze()` is called.
    public func freeze() {
        player.pause()
        isPlaying = false
        isFrozen = true
        updatePlaybackState(to: player.currentTime().seconds)
    }
    
    /// Freezes playback and waits until the currently displayed frame is available.
    @discardableResult
    public func freezeAndCaptureCurrentFrame() async -> UIImage? {
        freeze()
        return await captureCurrentFrame()
    }
    
    /// Unlocks playback controls. Playback remains paused until `play()` is called.
    public func unfreeze() {
        isFrozen = false
    }
    
    /// Pauses playback and advances by one video frame.
    public func stepForward() {
        step(by: 1)
    }
    
    /// Pauses playback and moves backward by one video frame.
    public func stepBackwards() {
        step(by: -1)
    }
    
    private func step(by frameCount: Int) {
        guard let item = player.currentItem else {
            return
        }
        
        player.pause()
        isPlaying = false
        currentFrame = nil
        item.step(byCount: frameCount)
        
        let steppedTime = item.currentTime().seconds
        updatePlaybackState(to: steppedTime)
    }
    
    /// Captures the video frame at `currentTime` and stores it in `currentFrame`.
    @discardableResult
    public func captureCurrentFrame() async -> UIImage? {
        guard let asset = player.currentItem?.asset else {
            currentFrame = nil
            return nil
        }
        
        isCapturingFrame = true
        defer {
            isCapturingFrame = false
        }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        let time = CMTime(
            seconds: currentTime,
            preferredTimescale: 600
        )
        
        do {
            let result = try await generator.image(at: time)
            let image = UIImage(cgImage: result.image)
            currentFrame = image
            return image
        } catch {
            currentFrame = nil
            return nil
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
            player.pause()
            isPlaying = false
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
        
        currentFrame = nil
        updatePlaybackState(to: clampedTime)
    }
    
    private func updatePlaybackState(to time: TimeInterval) {
        guard time.isFinite else {
            return
        }
        
        currentTime = time
        currentCameraInfo = closestCameraInfo(to: time)
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
