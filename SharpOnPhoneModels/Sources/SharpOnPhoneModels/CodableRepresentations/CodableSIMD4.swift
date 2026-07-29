//
//  CodableSIMD4.swift
//  SharpOnPhoneModels
//
//  Created by Aryan Rogye on 7/28/26.
//

import simd

public struct CodableSIMD4: Codable {
    var x: Float
    var y: Float
    var z: Float
    
    var pitch: Float
    var yaw: Float
    var roll: Float
    
    var simdRepresentation: simd_float4x4 {
        let translation = simd_float4x4(
            translation: SIMD3(x, y, z)
        )
        
        let pitchRotation = simd_float4x4(
            simd_quatf(
                angle: pitch,
                axis: SIMD3(1, 0, 0)
            )
        )
        
        let yawRotation = simd_float4x4(
            simd_quatf(
                angle: yaw,
                axis: SIMD3(0, 1, 0)
            )
        )
        
        let rollRotation = simd_float4x4(
            simd_quatf(
                angle: roll,
                axis: SIMD3(0, 0, 1)
            )
        )
        
        let rotation =
        yawRotation *
        pitchRotation *
        rollRotation
        
        return translation * rotation
    }
    
    init(_ simd: simd_float4x4) {
        x = simd.xPos
        y = simd.yPos
        z = simd.zPos
        
        pitch = simd.pitch
        yaw = simd.yaw
        roll = simd.roll
    }
}
