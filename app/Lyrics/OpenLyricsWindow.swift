//  OpenLyricsHUDIntent.swift
//  lyrics-v3

import AppIntents
import SwiftUI        // 用来取 SceneDelegate

@available(macOS 13, *)
struct OpenLyricsHUDIntent: AppIntent {

    static var title: LocalizedStringResource = "Show Lyrics Window"
    static var description = IntentDescription("Show the floating lyrics window on screen.")

    // Siri / Spotlight 时可说 “打开歌词悬浮窗”
    static var openAppWhenRun: Bool = true        // 触发时自动激活 App
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NSApp.activate(ignoringOtherApps: true)
        guard let delegate = AppDelegate.shared else {
            return .result()          // App 还没准备好
        }
        delegate.hud()
        return .result()
    }
}
