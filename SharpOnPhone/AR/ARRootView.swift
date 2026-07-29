//
//  ARRootView.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/26/26.
//

import SwiftUI
import SnapCoreEngine
import SharpOnPhoneUI
import SharpOnPhoneModels

enum ARChoice: String, CaseIterable {
    case savedProjects = "Saved Projects"
    case record = "Record"
}

struct ARRootView: View {
    @State private var manager = ARSessionManager()
    @State var cameraInfoStore = CameraInfoStore()
    @State private var selectedARChoice: ARChoice = .savedProjects
    
    @State private var error: String?
    @State private var showError: Bool = false
    
    var body: some View {
        ZStack {
            switch selectedARChoice {
            case .savedProjects:
                SavedProjectsView(
                    error: $error,
                    showError: $showError
                )
            case .record:
                ARRecordView(
                    manager: manager,
                    error: $error,
                    showError: $showError,
                    cameraInfoStore: cameraInfoStore
                )
            }
            
            ARChoicePicker(selectedARChoice: $selectedARChoice)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
    }
}

struct ARChoicePicker: View {
    
    @Binding var selectedARChoice: ARChoice
    
    var body: some View {
        VStack {
            Picker("", selection: $selectedARChoice) {
                ForEach(ARChoice.allCases, id: \.self) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            Spacer()
        }

    }
}
