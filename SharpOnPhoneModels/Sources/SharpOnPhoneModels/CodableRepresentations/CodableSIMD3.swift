//
//  CodableSIMD3.swift
//  SharpOnPhoneModels
//
//  Created by Aryan Rogye on 7/28/26.
//

import simd

public struct CodableSIMD3: Codable {
    var fx: Float
    var fy: Float
    var cx: Float
    var cy: Float
    
    var simdRepresentation: simd_float3x3 {
        simd_float3x3(
            columns: (
                SIMD3(fx, 0, 0),
                SIMD3(0, fy, 0),
                SIMD3(cx, cy, 1)
            )
        )
    }
    
    init(_ simd: simd_float3x3) {
        fx = simd.fx
        fy = simd.fy
        cx = simd.cx
        cy = simd.cy
    }
}
