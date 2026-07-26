//
//  HomeScreen.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/26/26.
//

import SwiftUI
import RealityKit
import UIKit

public struct HomeScreen: View {
    
    public let state: String
    public let isModelLoaded: Bool
    public var onLoadModel: () async throws -> Void
    public var onRunSharp: (UIImage, Data) async throws -> GaussianSplatResource.BufferResource
    
    public init(
        state: String,
        isModelLoaded: Bool,
        onLoadModel: @escaping () async throws -> Void,
        onRunSharp: @escaping (UIImage, Data) async throws -> GaussianSplatResource.BufferResource,
    ) {
        self.state = state
        self.onLoadModel = onLoadModel
        self.isModelLoaded = isModelLoaded
        self.onRunSharp = onRunSharp
    }
    
    @State private var error: String?
    @State private var showError: Bool = false
    
    public var body: some View {
        List {
            Text(state)
            if !isModelLoaded {
                LoadModelView(
                    error: $error,
                    showError: $showError,
                    onLoadModel: onLoadModel
                )
            } else {
                LoadedModelView(
                    error: $error,
                    showError: $showError,
                    onRunSharp: onRunSharp
                )
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
    }
}

struct LoadedModelView: View {
    
    @Binding var error: String?
    @Binding var showError: Bool
    public var onRunSharp: (UIImage, Data) async throws -> GaussianSplatResource.BufferResource
    
    @State private var isRunningSharp: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var isImageProcessing: Bool = false
    @State private var pickedImageURL: URL?
    
    // Store as UIImage
    @State private var loadedImage: UIImage?
    @State private var gaussianSplatBufferResource: GaussianSplatResource.BufferResource?
    
    var body: some View {
        Section("Model Settings") {
            Button("Pick Image") {
                showImagePicker = true
            }
            .disabled(isImageProcessing)
            .imagePicker(
                showPicker: $showImagePicker,
                isImageProcessing: $isImageProcessing,
                pickedImageURL: $pickedImageURL
            )
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                
                Button {
                    runSharp()
                } label: {
                    HStack {
                        Text("Run Sharp")
                        if isRunningSharp {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRunningSharp)
                
                if let gaussianSplatBufferResource {
                    NavigationLink {
                        GaussianSplatView(gaussianSplatBufferResource: gaussianSplatBufferResource)
                    } label: {
                        Text("View Gaussian Splat")
                    }
                }
            }
        }
        .task(id: pickedImageURL) {
            guard let pickedImageURL else {
                loadedImage = nil
                return
            }
            
            // Load UIImage off the main thread
            loadedImage = await Task.detached(priority: .userInitiated) {
                if let data = try? Data(contentsOf: pickedImageURL) {
                    return UIImage(data: data)
                }
                return nil
            }.value
        }
    }
    
    private func runSharp() {
        guard let pickedImageURL else { return }
        guard let image = loadedImage else { return }
        
        let data: Data
        do {
            data = try Data(contentsOf: pickedImageURL)
        } catch {
            self.error = "Failed to Get Image Data: \(error.localizedDescription)"
            self.showError = true
            return
        }
        
        if isRunningSharp { return }
        Task { @MainActor in
            isRunningSharp = true
            defer { isRunningSharp = false }
            do {
                self.gaussianSplatBufferResource = try await onRunSharp(image, data)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}


#Preview {
    
    @Previewable @State var isLoadingModel: Bool = false
    
    HomeScreen(
        state: "",
        isModelLoaded: false,
        onLoadModel: {
            try? await Task.sleep(
                for: .seconds(2)
            )
        },
        onRunSharp: { image, data in
            // 1. Simulate processing delay
            try? await Task.sleep(for: .seconds(2))
            
            let splatCount = 1_000
            
            // 2. Generate mock Float arrays for each attribute
            var positions = [Float]()
            var scales = [Float]()
            var rotations = [Float]()
            var opacities = [Float]()
            var colors = [Float]()
            
            positions.reserveCapacity(splatCount * 3)
            scales.reserveCapacity(splatCount * 3)
            rotations.reserveCapacity(splatCount * 4)
            opacities.reserveCapacity(splatCount)
            colors.reserveCapacity(splatCount * 3)
            
            for _ in 0..<splatCount {
                // Position: Random point in a [-1, 1] cube
                positions.append(contentsOf: [
                    Float.random(in: -1.0...1.0),
                    Float.random(in: -1.0...1.0),
                    Float.random(in: -1.0...1.0)
                ])
                
                // Scale: Small splats
                scales.append(contentsOf: [0.02, 0.02, 0.02])
                
                // Rotation: Identity quaternion [x, y, z, w]
                rotations.append(contentsOf: [0.0, 0.0, 0.0, 1.0])
                
                // Opacity: Mostly opaque
                opacities.append(Float.random(in: 0.5...1.0))
                
                // Color (RGB in [0, 1])
                colors.append(contentsOf: [
                    Float.random(in: 0.0...1.0),
                    Float.random(in: 0.0...1.0),
                    Float.random(in: 0.0...1.0)
                ])
            }
            
            // 3. LowLevelBuffer creation directly from Swift [Float] array pointer
            func makeLowLevelBuffer(from floats: [Float]) throws -> LowLevelBuffer {
                let byteSize = floats.count * MemoryLayout<Float>.size
                let buffer = try LowLevelBuffer(descriptor: .init(capacity: byteSize))
                
                floats.withUnsafeBufferPointer { sourcePtr in
                    guard let baseAddress = sourcePtr.baseAddress else { return }
                    let sourceBytes = UnsafeRawBufferPointer(start: baseAddress, count: byteSize)
                    buffer.withUnsafeMutableBytes { targetPtr in
                        targetPtr.copyMemory(from: sourceBytes)
                    }
                }
                
                return buffer
            }
            
            // 4. Create buffers and descriptors
            let posBuffer = try makeLowLevelBuffer(from: positions)
            let scaleBuffer = try makeLowLevelBuffer(from: scales)
            let rotBuffer = try makeLowLevelBuffer(from: rotations)
            let opacBuffer = try makeLowLevelBuffer(from: opacities)
            let colorBuffer = try makeLowLevelBuffer(from: colors)
            
            let posDesc = GaussianSplatResource.BufferDescriptor(
                buffer: posBuffer, format: .float3, stride: MemoryLayout<Float>.size * 3, offset: 0
            )
            let scaleDesc = GaussianSplatResource.BufferDescriptor(
                buffer: scaleBuffer, format: .float3, stride: MemoryLayout<Float>.size * 3, offset: 0
            )
            let rotDesc = GaussianSplatResource.BufferDescriptor(
                buffer: rotBuffer, format: .float4, stride: MemoryLayout<Float>.size * 4, offset: 0
            )
            let opacDesc = GaussianSplatResource.BufferDescriptor(
                buffer: opacBuffer, format: .float, stride: MemoryLayout<Float>.size * 1, offset: 0
            )
            let shDesc = GaussianSplatResource.BufferDescriptor(
                buffer: colorBuffer, format: .float3, stride: MemoryLayout<Float>.size * 3, offset: 0
            )
            
            // 5. Return BufferResource
            return try GaussianSplatResource.BufferResource(
                count: splatCount,
                position: posDesc,
                scale: scaleDesc,
                rotation: rotDesc,
                opacity: opacDesc,
                sphericalHarmonics: (shDesc, .zero)
            )
        }
    )
}
