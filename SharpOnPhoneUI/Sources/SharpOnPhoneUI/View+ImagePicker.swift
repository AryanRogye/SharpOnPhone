//
//  View+ImagePicker.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/26/26.
//

import SwiftUI
import PhotosUI

extension View {
    public func imagePicker(
        showPicker: Binding<Bool>,
        isImageProcessing: Binding<Bool>,
        pickedImageURL: Binding<URL?>
    ) -> some View {
        self
            .modifier(ImagePicker(
                showPicker: showPicker,
                isImageProcessing: isImageProcessing,
                pickedImageURL: pickedImageURL
            ))
    }
}

private struct ImagePicker: ViewModifier {
    @Binding var showPicker: Bool
    @Binding var isImageProcessing: Bool
    @Binding var pickedImageURL: URL?
    @State private var selectedItem : PhotosPickerItem?
    
    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: $showPicker,
                selection: $selectedItem,
                matching: .images
            )
            .onChange(of: selectedItem) { _, newValue in
                guard let newValue else { return }
                
                Task { @MainActor in
                    do {
                        isImageProcessing = true
                        defer {
                            isImageProcessing = false
                            selectedItem = nil
                        }
                        let pickedMovie = try await newValue.loadTransferable(
                            type: ImagePickerTransferable.self
                        )
                        pickedImageURL = pickedMovie?.imageURL
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
    }
}
