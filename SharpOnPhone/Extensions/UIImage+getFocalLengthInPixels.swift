//
//  UIImage+getFocalLengthInPixels.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/26/26.
//

import UIKit
import ImageIO

extension UIImage {
    /// Extracts focal length in pixels from image data EXIF metadata
    public static func getFocalLengthInPixels(from imageData: Data) -> Double? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
            return nil
        }
        
        // 1. Get image pixel width
        guard let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Double else {
            return nil
        }
        
        // 2. Option A: Use 35mm focal length equivalent directly (Standard 35mm film width = 36mm)
        if let focal35mm = exif[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Double {
            return (focal35mm * pixelWidth) / 36.0
        }
        
        // 3. Option B: Use actual focal length in mm
        if let focalLengthMM = exif[kCGImagePropertyExifFocalLength as String] as? Double {
            // Default mobile camera sensor width approximation (if specific sensor size unavailable)
            let estimatedSensorWidthMM: Double = 6.0
            return (focalLengthMM * pixelWidth) / estimatedSensorWidthMM
        }
        
        return nil
    }
}
