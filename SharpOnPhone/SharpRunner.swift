//
//  SharpRunner.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/26/26.
//

import CoreAI
import Foundation
import UIKit
import Metal
import RealityKit
import SharpOnPhoneUI

enum SharpRunnerError: LocalizedError {
    case coreAIModelNotFound
    case cantLoadModel(String)
    case mainFunctionLoadError(String)
    case mainFunctionNil
    case cantConvertImageToNDArray
    case cantCreateFocalLengthInPixels
    case modelNotLoaded
    case mainFunctionNotLoaded
    case errorCreatingGaussianSplatBufferResource(String)
    
    var errorDescription: String? {
        switch self {
        case .coreAIModelNotFound:
            return "CoreAI Model Not Found"
        case .cantLoadModel(let reason):
            return "Can't Load Model: \(reason)"
        case .mainFunctionLoadError(let reason):
            return "Main Function Load Error: \(reason)"
        case .mainFunctionNil:
            return "Main Function is Nil"
        case .cantConvertImageToNDArray:
            return "Cant Convert UIImage To NDArray (Float16, 1 × 3 × 1536 × 1536)"
        case .cantCreateFocalLengthInPixels:
            return "Cant Create Focal Length In Pixels"
        case .modelNotLoaded:
            return "Model Not Loaded"
        case .mainFunctionNotLoaded:
            return "Main Function Not Loaded"
        case .errorCreatingGaussianSplatBufferResource(let reason):
            return "Error Creating Gaussian Splat Buffer Resource: \(reason)"
        }
    }
}

enum SharpOutputError: LocalizedError {
    case meanVectorsMissing
    case singularValuesMissing
    case quaternionsMissing
    case colorsMissing
    case opacitiesMissing
    
    var errorDescription: String? {
        switch self {
        case .meanVectorsMissing:
            return "Output is missing expected mean vectors."
        case .singularValuesMissing:
            return "Output is missing expected singular values."
        case .quaternionsMissing:
            return "Output is missing expected quaternion rotations."
        case .colorsMissing:
            return "Output is missing expected color data."
        case .opacitiesMissing:
            return "Output is missing expected opacity values."
        }
    }
}

@Observable
@MainActor
final class SharpRunner {
    var state: String = "Idle"
    
    @ObservationIgnored
    private(set) var model: AIModel?
    @ObservationIgnored
    private(set) var mainFunction: InferenceFunction?
    
    func load() async throws {
        state = "Loading Model From Bundle"
        
        guard let modelPath = Bundle.main.url(
            forResource: "sharp_model",
            withExtension: "aimodel"
        ) else {
            throw SharpRunnerError.coreAIModelNotFound
        }
        
        state = "Creating AIModel Instance"
        
        do {
            model = try await AIModel(contentsOf: modelPath)
        } catch {
            throw SharpRunnerError.cantLoadModel(error.localizedDescription)
        }
        
        state = "Loading Main Function"
        
        do {
            guard let mainFunction = try model?.loadFunction(named: "main") else {
                throw SharpRunnerError.mainFunctionNil
            }
            
            self.mainFunction = mainFunction
        } catch {
            throw SharpRunnerError.mainFunctionLoadError(
                error.localizedDescription
            )
        }
        
        state = "Ready"
    }
    
    public func runSharp(on image: UIImage, disparityFactor: Double) async throws -> SharpSplatBufferResource {
        guard model != nil else {
            throw SharpRunnerError.modelNotLoaded
        }
        guard let mainFunction else {
            throw SharpRunnerError.mainFunctionNotLoaded
        }
        
        guard let imageNDArray = image.toFloat16NDArray() else {
            throw SharpRunnerError.cantConvertImageToNDArray
        }
        
        return try await runSharp(
            imageNDArray: imageNDArray,
            disparityFactor: disparityFactor,
            mainFunction: mainFunction
        )
    }
    
    public func runSharp(on image: UIImage, with data: Data) async throws -> SharpSplatBufferResource {
        
        guard model != nil else {
            throw SharpRunnerError.modelNotLoaded
        }
        guard let mainFunction else {
            throw SharpRunnerError.mainFunctionNotLoaded
        }
        
        guard let imageNDArray = image.toFloat16NDArray() else {
            throw SharpRunnerError.cantConvertImageToNDArray
        }
        
        // input of the model takes a disparity_factor: NDArray (Float16, 1)
        // disparity factor = focalLengthInPixels / imageWidth
        guard let focalLengthInPixels = UIImage.getFocalLengthInPixels(from: data) else {
            throw SharpRunnerError.cantCreateFocalLengthInPixels
        }
        let width = Double(image.size.width)
        let disparityFactor = focalLengthInPixels / width
        
        return try await runSharp(
            imageNDArray: imageNDArray,
            disparityFactor: disparityFactor,
            mainFunction: mainFunction
        )
    }
    
    /// Main Run Sharp Function
    private func runSharp(
        imageNDArray: NDArray,
        disparityFactor: Double,
        mainFunction: InferenceFunction
    ) async throws -> SharpSplatBufferResource {
        let disparityFactorNDArray = createDisparityNDArray(with: disparityFactor)
        
        print("Image NDArray: \(imageNDArray)")
        print("Disparity factor NDArray: \(disparityFactorNDArray)")
        
        
        var outputs: InferenceFunction.Outputs = try await mainFunction.run(inputs: [
            "image": imageNDArray,
            "disparity_factor": disparityFactorNDArray
        ])
        
        print("Output Count: \(outputs.count)")
        print("Outputs Name: \(outputs.names)")
        
        guard let mean_vectors = outputs.remove("mean_vectors")?.ndArray else {
            throw SharpOutputError.meanVectorsMissing
        }
        guard let singular_values = outputs.remove("singular_values")?.ndArray else {
            throw SharpOutputError.singularValuesMissing
        }
        guard let quaternions = outputs.remove("quaternions")?.ndArray else {
            throw SharpOutputError.quaternionsMissing
        }
        guard let colors = outputs.remove("colors")?.ndArray else {
            throw SharpOutputError.colorsMissing
        }
        guard let opacities = outputs.remove("opacities")?.ndArray else {
            throw SharpOutputError.opacitiesMissing
        }
        /// now we can print all to just see
        print("Mean Vectors: \(mean_vectors)")
        print("Singular Values: \(singular_values)")
        print("Quaternions: \(quaternions)")
        print("Colors: \(colors)")
        print("Opacities: \(opacities)")
        
        do {
            return try GaussianSplatBufferResourceCreator.makeSplatBufferResource(
                meanVectors: mean_vectors,
                singularValues: singular_values,
                quaternions: quaternions,
                colors: colors,
                opacities: opacities
            )
        } catch {
            throw SharpRunnerError.errorCreatingGaussianSplatBufferResource(error.localizedDescription)
        }
    }
    
    
    private func createDisparityNDArray(with disparityFactor: Double) -> NDArray {
        return NDArray(
            scalars: [Float16(disparityFactor)],
            shape: [1]
        )
    }
}

enum GaussianSplatBufferResourceCreator {
    static func makeSplatBufferResource(
        meanVectors: NDArray,
        singularValues: NDArray,
        quaternions: NDArray,
        colors: NDArray,
        opacities: NDArray
    ) throws -> GaussianSplatResource.BufferResource {
        
        /// Converts a Float16 Core AI NDArray into a Float32
        /// RealityKit LowLevelBuffer.
        func makeLowLevelBuffer(from array: NDArray) throws -> LowLevelBuffer {
            let elementCount = array.shape.reduce(1, *)
            let byteSize = elementCount * MemoryLayout<Float>.stride
            
            let buffer = try LowLevelBuffer(
                descriptor: .init(capacity: byteSize)
            )
            
            let float16View = array.view(as: Float16.self)
            
            buffer.withUnsafeMutableBytes { destinationBytes in
                let destinationValues = destinationBytes.bindMemory(
                    to: Float.self
                )
                
                float16View.withUnsafePointer { sourceValues, _, _ in
                    for index in 0..<elementCount {
                        destinationValues[index] = Float(
                            sourceValues[index]
                        )
                    }
                }
            }
            
            return buffer
        }

        /// RealityKit's color input is spherical-harmonic coefficients, not
        /// finished RGB. SHARP outputs final linear RGB colors, so convert
        /// each channel to the standard degree-zero SH coefficient:
        /// color = 0.5 + SH_C0 * coefficient.
        func makeDegreeZeroSHBuffer(from colors: NDArray) throws -> LowLevelBuffer {
            let elementCount = colors.shape.reduce(1, *)
            let byteSize = elementCount * MemoryLayout<Float>.stride
            let shC0: Float = 0.28209479177387814

            let buffer = try LowLevelBuffer(
                descriptor: .init(capacity: byteSize)
            )
            let float16View = colors.view(as: Float16.self)

            buffer.withUnsafeMutableBytes { destinationBytes in
                let destinationValues = destinationBytes.bindMemory(
                    to: Float.self
                )

                float16View.withUnsafePointer { sourceValues, _, _ in
                    for index in 0..<elementCount {
                        let color = Float(sourceValues[index])
                        destinationValues[index] = (color - 0.5) / shC0
                    }
                }
            }

            return buffer
        }
        
        /*
         Core AI output shapes:
         
         meanVectors:   [1, splatCount, 3]
         singularValues:[1, splatCount, 3]
         quaternions:   [1, splatCount, 4]
         colors:        [1, splatCount, 3]
         opacities:     [1, splatCount]
         
         shape[0] is the batch dimension.
         shape[1] is the actual number of splats.
         */
        let splatCount = meanVectors.shape[1]
        
        let positionBuffer = try makeLowLevelBuffer(
            from: meanVectors
        )
        
        let scaleBuffer = try makeLowLevelBuffer(
            from: singularValues
        )
        
        let rotationBuffer = try makeLowLevelBuffer(
            from: quaternions
        )
        
        let opacityBuffer = try makeLowLevelBuffer(
            from: opacities
        )
        
        let colorBuffer = try makeDegreeZeroSHBuffer(
            from: colors
        )
        
        let floatSize = MemoryLayout<Float>.stride
        
        let positionDescriptor =
        GaussianSplatResource.BufferDescriptor(
            buffer: positionBuffer,
            format: .float3,
            stride: floatSize * 3,
            offset: 0
        )
        
        let scaleDescriptor =
        GaussianSplatResource.BufferDescriptor(
            buffer: scaleBuffer,
            format: .float3,
            stride: floatSize * 3,
            offset: 0
        )
        
        let rotationDescriptor =
        GaussianSplatResource.BufferDescriptor(
            buffer: rotationBuffer,
            format: .float4,
            stride: floatSize * 4,
            offset: 0
        )
        
        let opacityDescriptor =
        GaussianSplatResource.BufferDescriptor(
            buffer: opacityBuffer,
            format: .float,
            stride: floatSize,
            offset: 0
        )
        
        let sphericalHarmonicsDescriptor =
        GaussianSplatResource.BufferDescriptor(
            buffer: colorBuffer,
            format: .float3,
            stride: floatSize * 3,
            offset: 0
        )
        
        return try GaussianSplatResource.BufferResource(
            count: splatCount,
            position: positionDescriptor,
            scale: scaleDescriptor,
            rotation: rotationDescriptor,
            opacity: opacityDescriptor,
            sphericalHarmonics: (
                sphericalHarmonicsDescriptor,
                .zero
            )
        )
    }
}
