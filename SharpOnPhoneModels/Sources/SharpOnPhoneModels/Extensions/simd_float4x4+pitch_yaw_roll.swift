//
//  simd_float4x4+pitch_yaw_roll.swift
//  SharpOnPhoneModels
//
//  Created by Aryan Rogye on 7/28/26.
//

import simd

public extension simd_float4x4 {
    var pitch: Float {
        asin(-self.columns.2.y)
    }
    var yaw: Float {
        atan2(self.columns.2.x, self.columns.2.z)
    }
    var roll: Float {
        atan2(self.columns.0.y, self.columns.1.y)
    }
}


