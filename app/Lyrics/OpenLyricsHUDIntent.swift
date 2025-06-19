//  OpenLyricsHUDIntent.swift
//  lyrics-v3

import AppIntents
import SwiftUI        // 用来取 SceneDelegate

@available(macOS 13, *)
struct OpenLyricsHUDIntent: AppIntent {

    static var title: LocalizedStringResource = "Show Lyrics HUD"
    static var description = IntentDescription("Show the floating lyrics window (HUD) on screen.")

    // Siri / Spotlight 时可说 “打开歌词悬浮窗”
    static var openAppWhenRun: Bool = true        // 触发时自动激活 App
    // MARK: - 执行
    @MainActor
    func perform() async throws -> some IntentResult {
        // 1️⃣ 取得 AppDelegate 单例
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else {
            return .result(dialog: "App not running")
        }

        // 2️⃣ 与菜单里的逻辑保持一致
        delegate.hud()

        // 3️⃣ 可以给个确认弹框（可选）
        return .result(dialog: "Lyrics HUD opened")
    }
}
