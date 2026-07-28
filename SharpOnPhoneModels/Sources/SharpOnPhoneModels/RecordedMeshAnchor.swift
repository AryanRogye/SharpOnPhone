//
//  RecordedMeshAnchor.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/27/26.
//

import ARKit

public struct RecordedMeshAnchor: Sendable {
    public let identifier: UUID
    public let transform: simd_float4x4
    public let vertices: [SIMD3<Float>]
    public let triangleIndices: [UInt32]
    public let classifications: [ARMeshClassification]

    public init(
        identifier: UUID,
        transform: simd_float4x4,
        vertices: [SIMD3<Float>],
        triangleIndices: [UInt32],
        classifications: [ARMeshClassification]
    ) {
        self.identifier = identifier
        self.transform = transform
        self.vertices = vertices
        self.triangleIndices = triangleIndices
        self.classifications = classifications
    }
    
    public nonisolated init(snapshotting meshAnchor: ARMeshAnchor) {
        let geometry = meshAnchor.geometry
        
        self.init(
            identifier: meshAnchor.identifier,
            transform: meshAnchor.transform,
            vertices: geometry.snapshotVertices(),
            triangleIndices: geometry.snapshotTriangleIndices(),
            classifications: geometry.snapshotClassifications()
        )
    }
}

private extension ARMeshGeometry {
    nonisolated func snapshotVertices() -> [SIMD3<Float>] {
        let source = vertices
        let baseAddress = source.buffer.contents()
        
        return (0..<source.count).map { index in
            let vertexAddress = baseAddress.advanced(
                by: source.offset + source.stride * index
            )
            let floatPointer = vertexAddress.assumingMemoryBound(to: Float.self)
            
            return SIMD3<Float>(
                floatPointer[0],
                floatPointer[1],
                floatPointer[2]
            )
        }
    }
    
    nonisolated func snapshotTriangleIndices() -> [UInt32] {
        let indexCount = faces.count * faces.indexCountPerPrimitive
        let baseAddress = faces.buffer.contents()
        
        return (0..<indexCount).map { index in
            let indexAddress = baseAddress.advanced(by: faces.bytesPerIndex * index)
            
            if faces.bytesPerIndex == MemoryLayout<UInt16>.size {
                return UInt32(indexAddress.assumingMemoryBound(to: UInt16.self).pointee)
            }
            
            return indexAddress.assumingMemoryBound(to: UInt32.self).pointee
        }
    }
    
    nonisolated func snapshotClassifications() -> [ARMeshClassification] {
        guard let source = classification else {
            return Array(repeating: .none, count: faces.count)
        }
        
        let baseAddress = source.buffer.contents()
        
        return (0..<faces.count).map { faceIndex in
            let classificationAddress = baseAddress.advanced(
                by: source.offset + source.stride * faceIndex
            )
            let rawValue = Int(
                classificationAddress.assumingMemoryBound(to: UInt8.self).pointee
            )
            
            return ARMeshClassification(rawValue: rawValue) ?? .none
        }
    }
}
