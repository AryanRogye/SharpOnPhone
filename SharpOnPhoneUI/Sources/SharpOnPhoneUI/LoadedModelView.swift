//
//  LoadedModelView.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/26/26.
//

import SwiftUI
import RealityKit

struct LoadedModelView: View {
    
    @Binding var error: String?
    @Binding var showError: Bool
    public var onRunSharp: (UIImage, Data) async throws -> SharpSplatBufferResource
    
    @State private var isRunningSharp: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var isImageProcessing: Bool = false
    @State private var pickedImageURL: URL?
    
    // Store as UIImage
    @State private var loadedImage: UIImage?
    @State private var gaussianSplatBufferResource: SharpSplatBufferResource?
    
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
