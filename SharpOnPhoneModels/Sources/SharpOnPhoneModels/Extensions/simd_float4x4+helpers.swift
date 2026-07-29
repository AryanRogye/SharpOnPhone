//
//  simd_float4x4+helpers.swift
//  SharpOnPhoneModels
//
//  Created by Aryan Rogye on 7/28/26.
//

import simd

public extension simd_float4x4 {
    func distance(to point: simd_float4x4) -> Float {
        let usX = self.xPos
        let usY = self.yPos
        let usZ = self.zPos
        
        let toX = point.xPos
        let toY = point.yPos
        let toZ = point.zPos
        
        return sqrt(pow(toX - usX, 2) + pow(toY - usY, 2) + pow(toZ - usZ, 2))
    }
    func midpoint(to other: simd_float4x4) -> SIMD3<Float> {
        let a = SIMD3<Float>(self.xPos, self.yPos, self.zPos)
        let b = SIMD3<Float>(other.xPos, other.yPos, other.zPos)
        return (a + b) / 2
    }
}
