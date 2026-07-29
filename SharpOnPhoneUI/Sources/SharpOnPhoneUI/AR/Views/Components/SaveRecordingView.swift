//
//  SaveRecordingView.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/28/26.
//

import SwiftUI

struct SaveRecordingView: View {

    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Recording name", text: $name)
            }
            .navigationTitle("Save Recording")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}
