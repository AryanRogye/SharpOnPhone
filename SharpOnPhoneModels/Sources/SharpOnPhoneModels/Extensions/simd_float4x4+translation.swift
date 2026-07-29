//
//  simd_float4x4+translation.swift
//  SharpOnPhoneModels
//
//  Created by Aryan Rogye on 7/28/26.
//

import simd

public extension simd_float4x4 {
    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        
        columns.3 = SIMD4(
            translation.x,
            translation.y,
            translation.z,
            1
        )
    }
}
