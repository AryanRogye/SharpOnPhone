//
//  ARViewPlayer.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/28/26.
//

import SwiftUI
import AVKit

public struct ARVideoPlayer: View {
    
    private let controller: ARVideoPlayerController
    
    public init(controller: ARVideoPlayerController) {
        self.controller = controller
    }
    
    public var body: some View {
        VideoPlayer(player: controller.player)
            .onAppear {
                controller.startObserving()
                controller.play()
            }
            .onDisappear {
                controller.stopObserving()
                controller.pause()
            }
    }
}
