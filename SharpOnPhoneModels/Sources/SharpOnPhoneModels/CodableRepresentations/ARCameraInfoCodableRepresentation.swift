//
//  ARCameraInfoCodableRepresentation.swift
//  SharpOnPhoneModels
//
//  Created by Aryan Rogye on 7/28/26.
//

import Foundation

public struct ARCameraInfoCodableRepresentation: Codable {
    public let cameraTransform: CodableSIMD4
    public let intrinsics: CodableSIMD3
    public let timestamp: TimeInterval
    
    public init(from cameraInfo: ARCameraInfo) {
        self.cameraTransform = .init(cameraInfo.cameraTransform)
        self.intrinsics = .init(cameraInfo.intrinsics)
        self.timestamp = cameraInfo.timestamp
    }
}
