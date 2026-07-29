//
//  ARCameraInfo.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/27/26.
//

import Foundation
import simd

public struct ARCameraInfo: Sendable {
    /**
     * contains x,y,z
     * [
     * [ rx,  ry,  rz,  0.0 ],   // <- Rotation (X axis)
     * [ rx,  ry,  rz,  0.0 ],   // <- Rotation (Y axis)
     * [ rx,  ry,  rz,  0.0 ],   // <- Rotation (Z axis)
     * [  X,   Y,   Z,  1.0 ]    // <- Position (X, Y, Z in meters)
     * ]
     *
     * Standing still at (0, 0, 0) looking straight ahead
     * cameraTransform = simd_float4x4(
     *  [1.0,  0.0,  0.0,  0.0],  // rx == 1 because thats looking ahead
     *  [0.0,  1.0,  0.0,  0.0],
     *  [0.0,  0.0,  1.0,  0.0],
     *  [0.0,  0.0,  0.0,  1.0]   // Position: X=0, Y=0, Z=0
     * )
     *
     * Now, you step 2 meters to the right and raise the phone 1 meter up:
     * cameraTransform = simd_float4x4(
     *  [1.0,  0.0,  0.0,  0.0],
     *  [0.0,  1.0,  0.0,  0.0],
     *  [0.0,  0.0,  1.0,  0.0],
     *  [2.0,  1.0,  0.0,  1.0]   // Position: X=2.0, Y=1.0, Z=0.0
     * )
     * the X went to the right 2 meters so X += 2 and the Y went up 1 meter so Y += 1
     */
    public let cameraTransform: simd_float4x4
    /**
     * // simd_float3x3
     * [
     *   SIMD3<Float>( fx,   0,   0 ),  // Column 0
     *   SIMD3<Float>(  0,  fy,   0 ),  // Column 1
     *   SIMD3<Float>( cx,  cy,   1 )   // Column 2
     * ]
     * f_x, f_y (Focal Length in Pixels):
     * Tells you how wide or zoomed-in the lens is.
     * Higher values = narrow/zoomed lens (telephoto).
     * Lower values = wide-angle lens.
     *
     * c_x, c_y (Principal Point in Pixels):
     * Usually the exact center of the image (image.width / 2, image.height / 2).
     * Tells you where the lens optical center is located in pixel coordinates.
     */
    public let intrinsics: simd_float3x3
    public let timestamp: TimeInterval
    
    
    var codableRepresentation: ARCameraInfoCodableRepresentation {
        .init(from: self)
    }
    
    public init(
        from representation: ARCameraInfoCodableRepresentation
    ) {
        self.init(
            cameraTransform: representation.cameraTransform.simdRepresentation,
            intrinsics: representation.intrinsics.simdRepresentation,
            timestamp: representation.timestamp
        )
    }

    public init(
        cameraTransform: simd_float4x4,
        intrinsics: simd_float3x3,
        timestamp: TimeInterval
    ) {
        self.cameraTransform = cameraTransform
        self.intrinsics = intrinsics
        self.timestamp = timestamp
    }
}

public extension ARCameraInfo {
    static let mock: [ARCameraInfo] = {
        let intrinsics = simd_float3x3(
            SIMD3<Float>(1_200, 0, 0),
            SIMD3<Float>(0, 1_200, 0),
            SIMD3<Float>(960, 540, 1)
        )
        
        return (0..<120).map { frame in
            let timestamp = Double(frame) / 60.0
            let progress = Float(frame) / 119.0
            
            // Simulate walking forward while drifting right.
            let position = SIMD3<Float>(
                progress * 1.5,
                1.6,
                -progress * 3.0
            )
            
            // Slowly rotate the camera to the right.
            let yaw = progress * .pi / 4
            
            let rotation = simd_float4x4(
                simd_quatf(
                    angle: yaw,
                    axis: SIMD3<Float>(0, 1, 0)
                )
            )
            
            var transform = rotation
            transform.columns.3 = SIMD4<Float>(
                position.x,
                position.y,
                position.z,
                1
            )
            
            return ARCameraInfo(
                cameraTransform: transform,
                intrinsics: intrinsics,
                timestamp: timestamp
            )
        }
    }()
}
