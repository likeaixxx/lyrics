//
//  LyricsApp.swift
//  lyrics-v3
//
//  Created by likeai on 2024/5/16.
//

import Foundation
import SwiftUI

@main
@available(macOS 13.0, *)
struct LyricsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("Settings not available.")
        }
    }
}
