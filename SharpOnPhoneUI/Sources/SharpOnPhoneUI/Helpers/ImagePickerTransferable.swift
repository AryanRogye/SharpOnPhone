//
//  ImagePickerTransferable.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/26/26.
//

import SwiftUI

struct ImagePickerTransferable: Transferable {
    let imageURL: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .image) { exportingFile in
            return .init(exportingFile.imageURL)
        } importing: { ReceivedTransferredFile in
            let original = ReceivedTransferredFile.file
            let fileExtension = original.pathExtension.isEmpty ? "jpg" : original.pathExtension
            let copiedFile = URL.documentsDirectory.appending(
                path: "picked-image-\(UUID().uuidString).\(fileExtension)"
            )
            try FileManager.default.copyItem(at: original, to: copiedFile)
            return .init(imageURL: copiedFile)
        }
    }
}
