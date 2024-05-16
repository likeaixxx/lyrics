//
//  LyricsApp.swift
//  lyrics-v3
//
//  Created by 陈爱全 on 2024/5/16.
//

import Foundation
import SwiftUI

@main
struct LyricsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("Settings not available.")
        }
    }
}
