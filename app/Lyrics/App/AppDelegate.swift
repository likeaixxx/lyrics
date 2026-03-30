import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!

    // Core Components
    var lyricsViewModel: LyricsViewModel!
    var statusMenuController: StatusMenuController!

    // Services
    private let spotifyService = SpotifyService.shared
    private let lyricsService = LyricsService.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Initialize ViewModel
        lyricsViewModel = LyricsViewModel(spotifyService: spotifyService, lyricsService: lyricsService)

        // Initialize UI Controller
        statusMenuController = StatusMenuController(viewModel: lyricsViewModel)

        // Request Permissions
        NotificationService.shared.requestAuthorization()

        print("✅ App Launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("❌ App Terminating")
    }

    // Kept for backward compatibility if any weird view needs it, but usage should be minimized
    static var viewContext: LyricsViewModel {
        return shared.lyricsViewModel
    }

    // MARK: - Intent Helpers

    func openOrClose() {
        statusMenuController.toggleHUD()
    }

    func hud() {
        statusMenuController.toggleHUD()
    }

    func _refresh(r: Bool) {
        // 'r' ignored, just fetch
        lyricsViewModel.fetchLyrics()
    }
}
