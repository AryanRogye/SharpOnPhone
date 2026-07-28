//
//  ARCameraFrame.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/26/26.
//

import ARKit

public struct ARCameraFrame: @unchecked Sendable {
    public let image: CVPixelBuffer
    public let cameraTransform: simd_float4x4
    public let intrinsics: simd_float3x3
    public let timestamp: TimeInterval
    
    public init(
        image: CVPixelBuffer,
        cameraTransform: simd_float4x4,
        intrinsics: simd_float3x3,
        timestamp: TimeInterval
    ) {
        self.image = image
        self.cameraTransform = cameraTransform
        self.intrinsics = intrinsics
        self.timestamp = timestamp
    }
}
