import Foundation
import ScriptingBridge
import Combine
import AppKit

final class SpotifyService: ObservableObject {
    static let shared = SpotifyService()

    @Published var currentTrack: SpotifyTrack?
    @Published var playerState: SpotifyEPlS = .stopped
    @Published var playerPosition: Double = 0.0

    private var spotifyApp: SpotifyApplication?
    private var cancellables = Set<AnyCancellable>()

    // Playback Observer
    private var playbackObserver: NSObjectProtocol?

    init() {
        self.spotifyApp = SBApplication(bundleIdentifier: "com.spotify.client")
        setupPlaybackObserver()
        checkPlaybackState()
    }

    deinit {
        if let observer = playbackObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    var isPlaying: Bool {
        guard let app = spotifyApp else { return false }
        return app.playerState == .playing
    }

    func setupPlaybackObserver() {
        playbackObserver = DistributedNotificationCenter.default()
            .addObserver(
                forName: Notification.Name("com.spotify.client.PlaybackStateChanged"),
                object: nil,
                queue: .main
            ) { [weak self] note in
                self?.handlePlaybackChange(note: note)
            }
    }

    private func checkPlaybackState() {
        guard let spotifyApp = self.spotifyApp else { return }

        // Update local state from Spotify App directly
        self.playerState = spotifyApp.playerState ?? .stopped
        self.currentTrack = spotifyApp.currentTrack
        self.playerPosition = spotifyApp.playerPosition ?? 0.0

        // Ensure running if paused
        if self.playerState == .playing && !(spotifyApp.isRunning ?? false) {
             // Edge case: sometimes reports playing but app is closed?
        }
    }

    private func handlePlaybackChange(note: Notification) {
        checkPlaybackState()
    }

    func next(currentTrackID: String?) -> SpotifyTrack? {
        guard let spotify = self.spotifyApp,
              let _ = spotify.currentTrack?.name,
              spotify.playerState == .playing else {
            return nil
        }

        guard let currentTrack = spotify.currentTrack else {
            return nil
        }

        let id = currentTrack.id?()
        if id != currentTrackID {
            // Logic to force update if needed, but generally we just return the track
            // The original code had a weird loop here, simplifying for now
            return currentTrack
        }
        return nil
    }

    func getCurrentPosition() -> Double {
        return spotifyApp?.playerPosition ?? 0.0
    }
}
