//
//  LoadModelView.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/26/26.
//

import SwiftUI

struct LoadModelView: View {
    
    @State public var isLoadingModel: Bool = false
    @Binding var error: String?
    @Binding var showError: Bool
    public var onLoadModel: () async throws -> Void
    
    var body: some View {
        Button {
            loadModel()
        } label: {
            HStack {
                if isLoadingModel {
                    Text("Loading Model")
                } else {
                    Text("Load Model")
                }
                
                if isLoadingModel {
                    ProgressView()
                }
            }
        }
        .disabled(isLoadingModel)
    }
    
    private func loadModel() {
        if isLoadingModel { return }
        Task {
            isLoadingModel = true
            defer { isLoadingModel = false }
            do {
                try await onLoadModel()
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}
