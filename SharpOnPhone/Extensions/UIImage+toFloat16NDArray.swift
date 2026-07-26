//
//  UIImage+toFloat16NDArray.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/26/26.
//

import UIKit
import Accelerate
import CoreAI

extension UIImage {
    func toFloat16NDArray() -> NDArray? {
        let targetSize = CGSize(width: 1536, height: 1536)
        
        // 1. Redraw UIImage into a 1536x1536 32-bit RGBA context
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1
        rendererFormat.opaque = true
        let orientedImage = UIGraphicsImageRenderer(
            size: targetSize,
            format: rendererFormat
        ).image { _ in
            // UIImage.draw respects imageOrientation, unlike drawing cgImage
            // directly into a CGContext.
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let cgImage = orientedImage.cgImage else { return nil }
        let bytesPerPixel = 4
        let totalPixels = 1536 * 1536
        var rawBytes = [UInt8](repeating: 0, count: totalPixels * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &rawBytes,
            width: 1536,
            height: 1536,
            bitsPerComponent: 8,
            bytesPerRow: 1536 * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        
        // 2. Convert UInt8 (0...255) -> Float16 (0.0...1.0) and split RGBA -> Planar RGB
        var scalars = [Float16](repeating: 0, count: 1 * 3 * 1536 * 1536)
        
        let redOffset = 0
        let greenOffset = totalPixels
        let blueOffset = totalPixels * 2
        
        for i in 0..<totalPixels {
            let byteIndex = i * 4
            scalars[redOffset + i]   = Float16(rawBytes[byteIndex]) / 255.0
            scalars[greenOffset + i] = Float16(rawBytes[byteIndex + 1]) / 255.0
            scalars[blueOffset + i]  = Float16(rawBytes[byteIndex + 2]) / 255.0
        }
        
        // 3. Instantiate the NDArray
        return NDArray(
            scalars: scalars,
            shape: [1, 3, 1536, 1536]
        )
    }
}
