//
//  ARCameraView.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/27/26.
//

import SwiftUI
import SnapCoreEngine

struct ARCameraView: View {
    
    @State private var viewport = MetalImageViewport()
    let texture: YCbCrTextures
    
    var body: some View {
            GeometryReader { geometry in
                MetalImageView(
                    viewport: $viewport,
                    texture: texture
                )
                .frame(
                    width: geometry.size.height,
                    height: geometry.size.width
                )
                .rotationEffect(.degrees(90))
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
            }
            .ignoresSafeArea()
    }
}
