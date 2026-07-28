//
//  ContentView.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/26/26.
//

import SwiftUI
import SharpOnPhoneUI

struct ContentView: View {
    
    @State var sharpRunner = SharpRunner()
    
    var isModelLoaded: Bool {
        return sharpRunner.model != nil || sharpRunner.mainFunction != nil
    }
    
    var body: some View {
        TabView {
            Tab {
                NavigationStack {
                    ConvertScreen(
                        state: sharpRunner.state,
                        isModelLoaded: isModelLoaded,
                        onLoadModel: {
                            try await sharpRunner.load()
                        },
                        onRunSharp: { image, data in
                            try await sharpRunner.runSharp(on: image, with: data)
                        }
                    )
                }
            } label: {
                Label("Convert", systemImage: "wand.and.rays")
            }
            
            Tab {
                ARTestView()
            } label: {
                Label("AR", systemImage: "arkit")
            }
        }
    }
}

#Preview {
    ContentView()
}
