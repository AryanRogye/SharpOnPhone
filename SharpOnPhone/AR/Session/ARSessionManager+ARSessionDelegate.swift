//
//  ARSessionManager+delegate.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/28/26.
//

import ARKit
import SnapCoreEngine
import SharpOnPhoneModels

extension ARSessionManager: ARSessionDelegate {

    /// ARKit calls this when new anchors are introduced
    nonisolated func session(
        _ session: ARSession,
        didAdd anchors: [ARAnchor]
    ) {

        guard let result = createMeshSnapshots(anchors: anchors) else {
            return
        }

        Task { @MainActor in
            processMeshAnchors(
                generation: result.generation,
                result.snapshots
            )
        }
    }

    /// ARKit calls this when anchors that already exist change
    nonisolated func session(
        _ session: ARSession,
        didUpdate anchors: [ARAnchor]
    ) {
        guard let result = createMeshSnapshots(anchors: anchors) else {
            return
        }
        
        Task { @MainActor in
            processMeshAnchors(
                generation: result.generation,
                result.snapshots
            )
        }
    }

    nonisolated func session(
        _ session: ARSession,
        didUpdate frame: ARFrame
    ) {
        let trackingDescription = createTrackingDescription(from: frame)
        let textures: YCbCrTextures? = createTexture(from: frame)

        let transform = frame.camera.transform
        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )

        Task { @MainActor in

            // if we're recording and user hasnt pressed stop
            if isRecording, !isFinishingRecording {
                appendRecordingFrame(frame)
            }
            imageTexture = textures
            cameraPosition = position
            trackingState = trackingDescription
        }
    }
}

// MARK: - Frame Processing
extension ARSessionManager {
    private func appendRecordingFrame(_ frame: ARFrame) {
        // Only process this frame if it was captured after the tracking reset began
        guard frame.timestamp > resetFrameTimestamp else {
            return
        }

        // this will only be true when we first press record
        if isWaitingForTrackingReset {
            // pendingRecordingURL is only set by starting recording
            guard
                case .normal = frame.camera.trackingState,
                let pendingRecordingURL
            else {
                return
            }

            // start recording and reset flags
            videoRecorder.startRecording(to: pendingRecordingURL)
            self.pendingRecordingURL = nil
            // by setting this to false we never enter this block again
            isWaitingForTrackingReset = false
            // remove stale meshs and start capture
            // this should call begin because at this point we have captured our first "frame"
            beginMeshCapture()

            guard let result = createMeshSnapshots(anchors: frame.anchors) else {
                return
            }

            processMeshAnchors(
                generation: result.generation,
                result.snapshots
            )
        }

        // check if the last frame we processed is moving ahead in time
        if let lastSubmittedFrameTimestamp {
            guard frame.timestamp > lastSubmittedFrameTimestamp else {
                return
            }
        }

        // value is only set when we start a recording
        guard let recordingID else {
            return
        }

        // mark that this frame was the last frame we processed so we can make sure
        // we're always moving ahead
        lastSubmittedFrameTimestamp = frame.timestamp

        let cameraTransform = frame.camera.transform
        let intrinsics = frame.camera.intrinsics

        videoRecorder.append(
            pixelBuffer: frame.capturedImage,
            timestamp: frame.timestamp
        ) { [weak self] elapsedTime in
            Task { @MainActor [weak self] in
                guard self?.recordingID == recordingID else {
                    return
                }

                self?.cameraInfo.append(
                    ARCameraInfo(
                        cameraTransform: cameraTransform,
                        intrinsics: intrinsics,
                        timestamp: elapsedTime
                    )
                )
            }
        }
    }
}

// MARK: - Helpers
extension ARSessionManager {
    
    /// A snapshot container for recorded mesh data, safe to share across threads.
    /// This struct is inherently thread-safe because it is immutable and conforms to Sendable.
    private struct MeshSnapshotResult: Sendable {
        let snapshots: [RecordedMeshAnchor]
        let generation: UInt64
    }
    
    /// A non-isolated helper that processes raw ARKit anchors into value-type snapshots.
    ///
    /// function is purposely nonisolated because `ARSessionDelegate` may be
    /// called from any background thread, It performs heavy mapping operations off the
    /// main actor. should be called before we call `processMeshAnchors`
    nonisolated private func createMeshSnapshots(anchors: [ARAnchor]) -> MeshSnapshotResult? {
        
        // capture generation beforehand, guard here because this will
        // return nil if we're not recording
        guard let generation = currentMeshCaptureGeneration() else {
            return nil
        }
        
        // create snapshot, check `RecordedMeshAnchor` initializer for process
        let snapshots = anchors.compactMap { anchor -> RecordedMeshAnchor? in
            guard let meshAnchor = anchor as? ARMeshAnchor else {
                return nil
            }
            
            return RecordedMeshAnchor(snapshotting: meshAnchor)
        }
        return .init(
            snapshots: snapshots,
            generation: generation
        )
    }
}

extension ARSessionManager {
    nonisolated internal func createTexture(from frame: ARFrame) -> YCbCrTextures? {
        do {
            return try MetalHelpers.makeYCbCrTextures(
                from: frame.capturedImage
            )
        } catch {
            Task { @MainActor in
                trackingState += " - Texture creation failed"
            }
            return nil
        }
    }

    nonisolated private func createTrackingDescription(from frame: ARFrame) -> String {
        let trackingDescription: String

        switch frame.camera.trackingState {
        case .normal:
            trackingDescription = "Normal"

        case .notAvailable:
            trackingDescription = "Unavailable"

        case .limited(let reason):
            trackingDescription = "Limited: \(reason)"

        @unknown default:
            trackingDescription = "Unknown"
        }

        return trackingDescription
    }
}
