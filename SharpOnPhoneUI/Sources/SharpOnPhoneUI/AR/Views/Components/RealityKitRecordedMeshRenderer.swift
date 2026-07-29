//
//  RealityKitRecordedMeshRenderer.swift
//  SharpOnPhoneUI
//
//  Created by Codex on 7/28/26.
//

import ARKit
import RealityKit
import UIKit
import SharpOnPhoneModels

@MainActor
enum RealityKitRecordedMeshRenderer {
    static let rootName = "RecordedEnvironment"

    static func makeRoot(
        from recordedMeshes: [UUID: RecordedMeshAnchor]
    ) -> Entity {
        let root = Entity()
        root.name = rootName

        for anchor in recordedMeshes.values {
            guard let model = makeModel(for: anchor) else {
                continue
            }

            let anchorEntity = Entity()
            anchorEntity.name = "mesh_\(anchor.identifier.uuidString)"
            anchorEntity.transform = Transform(matrix: anchor.transform)
            anchorEntity.addChild(model)
            root.addChild(anchorEntity)
        }

        return root
    }

    private static func makeModel(
        for anchor: RecordedMeshAnchor
    ) -> ModelEntity? {
        guard !anchor.vertices.isEmpty else {
            return nil
        }

        let triangleCount = anchor.triangleIndices.count / 3
        var validIndices: [UInt32] = []
        var materialIndices: [UInt32] = []
        validIndices.reserveCapacity(triangleCount * 3)
        materialIndices.reserveCapacity(triangleCount)

        for faceIndex in 0..<triangleCount {
            let indexOffset = faceIndex * 3
            let triangle = anchor.triangleIndices[
                indexOffset..<(indexOffset + 3)
            ]

            guard triangle.allSatisfy({
                Int($0) < anchor.vertices.count
            }) else {
                continue
            }

            validIndices.append(contentsOf: triangle)
            materialIndices.append(
                materialIndex(
                    for: anchor.classifications[safe: faceIndex]
                )
            )
        }

        guard !validIndices.isEmpty else {
            return nil
        }

        var descriptor = MeshDescriptor(
            name: anchor.identifier.uuidString
        )
        descriptor.positions = MeshBuffers.Positions(anchor.vertices)
        descriptor.primitives = .triangles(validIndices)
        descriptor.materials = .perFace(materialIndices)

        guard let mesh = try? MeshResource.generate(
            from: [descriptor]
        ) else {
            return nil
        }

        return ModelEntity(
            mesh: mesh,
            materials: materials
        )
    }

    private static func materialIndex(
        for classification: ARMeshClassification?
    ) -> UInt32 {
        switch classification {
        case .wall:
            return 0
        case .floor:
            return 1
        default:
            return 2
        }
    }

    private static var materials: [UnlitMaterial] {
        [
            makeMaterial(
                color: UIColor(
                    red: 0.20,
                    green: 0.62,
                    blue: 1.00,
                    alpha: 0.42
                )
            ),
            makeMaterial(
                color: UIColor(
                    red: 0.14,
                    green: 0.88,
                    blue: 0.62,
                    alpha: 0.42
                )
            ),
            makeMaterial(
                color: UIColor(
                    white: 0.72,
                    alpha: 0.24
                )
            )
        ]
    }

    private static func makeMaterial(
        color: UIColor
    ) -> UnlitMaterial {
        var material = UnlitMaterial(color: color)
        material.faceCulling = .none
        return material
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
