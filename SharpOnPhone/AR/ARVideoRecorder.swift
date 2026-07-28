//
//  ARVideoRecorder.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/26/26.
//

import AVFoundation

final class ARVideoRecorder: @unchecked Sendable {
    
    private let writingQueue = DispatchQueue(
        label: "com.aryan.SharpOnPhone.video-writing"
    )
    
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private var outputURL: URL?
    private var firstFrameTimestamp: TimeInterval?
    
    private(set) var isRecording = false
    
    func startRecording(to url: URL) {
        writingQueue.async { [weak self] in
            guard let self else {
                return
            }
            
            try? FileManager.default.removeItem(at: url)
            
            outputURL = url
            firstFrameTimestamp = nil
            isRecording = true
        }
    }
    
    func append(
        pixelBuffer: CVPixelBuffer,
        timestamp: TimeInterval
    ) {
        writingQueue.async { [weak self] in
            guard let self, isRecording else {
                return
            }
            
            do {
                if writer == nil {
                    try prepareWriter(
                        pixelBuffer: pixelBuffer,
                        firstTimestamp: timestamp
                    )
                }
                
                guard
                    let writer,
                    let videoInput,
                    let pixelBufferAdaptor,
                    writer.status == .writing,
                    videoInput.isReadyForMoreMediaData,
                    let firstFrameTimestamp
                else {
                    return
                }
                
                let elapsedTime = timestamp - firstFrameTimestamp
                
                let presentationTime = CMTime(
                    seconds: elapsedTime,
                    preferredTimescale: 600
                )
                
                let didAppend = pixelBufferAdaptor.append(
                    pixelBuffer,
                    withPresentationTime: presentationTime
                )
                
                if !didAppend {
                    print(
                        "Failed to append frame:",
                        writer.error?.localizedDescription ?? "Unknown error"
                    )
                }
            } catch {
                print("Video writer failed:", error)
            }
        }
    }
    
    func stopRecording(
        completion: @escaping @Sendable (Result<URL, Error>) -> Void
    ) {
        writingQueue.async { [weak self] in
            guard
                let self,
                isRecording,
                let writer,
                let videoInput,
                let outputURL
            else {
                return
            }
            
            isRecording = false
            videoInput.markAsFinished()
            
            writer.finishWriting {
                if let error = writer.error {
                    completion(.failure(error))
                } else {
                    completion(.success(outputURL))
                }
                
                self.writingQueue.async {
                    self.reset()
                }
            }
        }
    }
    
    private func prepareWriter(
        pixelBuffer: CVPixelBuffer,
        firstTimestamp: TimeInterval
    ) throws {
        guard let outputURL else {
            throw RecordingError.missingOutputURL
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let writer = try AVAssetWriter(
            outputURL: outputURL,
            fileType: .mov
        )
        
        let compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: 20_000_000,
            AVVideoExpectedSourceFrameRateKey: 60,
            AVVideoMaxKeyFrameIntervalKey: 60
        ]
        
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
        
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: outputSettings
        )
        
        videoInput.expectsMediaDataInRealTime = true
        
        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String:
                CVPixelBufferGetPixelFormatType(pixelBuffer),
            
            kCVPixelBufferWidthKey as String:
                width,
            
            kCVPixelBufferHeightKey as String:
                height
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: sourceAttributes
        )
        
        guard writer.canAdd(videoInput) else {
            throw RecordingError.cannotAddVideoInput
        }
        
        writer.add(videoInput)
        
        guard writer.startWriting() else {
            throw writer.error ?? RecordingError.cannotStartWriting
        }
        
        writer.startSession(atSourceTime: .zero)
        
        self.writer = writer
        self.videoInput = videoInput
        self.pixelBufferAdaptor = adaptor
        self.firstFrameTimestamp = firstTimestamp
    }
    
    private func reset() {
        writer = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        outputURL = nil
        firstFrameTimestamp = nil
    }

}


extension ARVideoRecorder {
    
    enum RecordingError: LocalizedError {
        case missingOutputURL
        case cannotAddVideoInput
        case cannotStartWriting
        
        var errorDescription: String? {
            switch self {
            case .missingOutputURL:
                return "Missing output URL"
            case .cannotAddVideoInput:
                return "Cannot add video input"
            case .cannotStartWriting:
                return "Cannot start writing"
            }
        }
    }
}
