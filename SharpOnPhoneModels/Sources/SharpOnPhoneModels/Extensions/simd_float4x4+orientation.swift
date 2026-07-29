//
//  simd_float4x4+orientation.swift
//  SharpOnPhoneModels
//
//  Created by Aryan Rogye on 7/28/26.
//

import simd

public extension simd_float4x4 {
    
    var orientation: simd_quatf {
        simd_quatf(self)
    }
}
