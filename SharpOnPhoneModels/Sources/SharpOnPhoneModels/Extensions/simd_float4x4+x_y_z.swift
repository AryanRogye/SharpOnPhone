//
//  simd_float4x4+x_y_z.swift
//  SharpOnPhoneModels
//
//  Created by Aryan Rogye on 7/28/26.
//

import simd

public extension simd_float4x4 {
    var xPos: Float {
        self.columns.3.x
    }
    
    var yPos: Float {
        self.columns.3.y
    }
    
    var zPos: Float {
        self.columns.3.z
    }
}

