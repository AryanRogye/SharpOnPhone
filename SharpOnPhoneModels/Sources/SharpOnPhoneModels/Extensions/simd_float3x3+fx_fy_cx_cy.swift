//
//  simd_float3x3+fx_fy_cx_cy.swift
//  SharpOnPhoneModels
//
//  Created by Aryan Rogye on 7/28/26.
//

import simd

public extension simd_float3x3 {
    var fx: Float { columns.0.x }
    var fy: Float { columns.1.y }
    var cx: Float { columns.2.x }
    var cy: Float { columns.2.y }
}

