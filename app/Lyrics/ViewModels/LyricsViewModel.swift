import Foundation
import Combine
import SwiftUI

final class LyricsViewModel: ObservableObject {

    /// Snapshot of (position, wall-clock time) taken whenever position is polled from Spotify.
    /// Active word-timing lines use this to extrapolate position locally at display-link rate
    /// without requiring the VM timer to fire at 60fps.
    struct PositionAnchor: Equatable {
        let position: Double
        let date: Date
        static let zero = PositionAnchor(position: 0, date: Date())
    }
    // Current Track Info
    @Published var song: String = ""
    @Published var singer: String = ""
    @Published var currentTrackID: String = ""

    // Lyrics Data
    @Published var lyricLines: [LyricLine] = []
    @Published var lyricId: String = ""
    @Published var offset: Int64 = 0
    @Published var activeIndex: Int = -1

    // Playback State
    @Published var position: Double = 0.0
    @Published var isPlaying: Bool = false
    @Published var positionAnchor: PositionAnchor = .zero

    // Configuration
    @Published var host: String {
        didSet {
            UserDefaults.standard.set(host, forKey: "api_host")
        }
    }

    // Services
    private let spotifyService: SpotifyService
    private let lyricsService: LyricsService

    private var cancellables = Set<AnyCancellable>()
    private var timer: DispatchSourceTimer?
    private let updateQueue = DispatchQueue(label: "com.lyrics.updateQueue", qos: .userInteractive)

    init(spotifyService: SpotifyService = .shared, lyricsService: LyricsService = .shared) {
        self.spotifyService = spotifyService
        self.lyricsService = lyricsService

        self.host = UserDefaults.standard.string(forKey: "api_host") ?? "https://127.0.0.1:8331"

        setupSubscriptions()
    }

    private func setupSubscriptions() {
        // Subscribe to Spotify updates
        spotifyService.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.handleTrackChange(track)
            }
            .store(in: &cancellables)

        spotifyService.$playerState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isPlaying = (state == .playing)
                if state == .playing {
                    self?.scheduleNextTick(options: .immediate)
                } else {
                    self?.timer?.cancel()
                }
            }
            .store(in: &cancellables)

        spotifyService.$playerPosition
             .receive(on: DispatchQueue.main)
             .sink { [weak self] pos in
                 // Sync position occasionally or on track change
                 if abs((self?.position ?? 0) - pos) > 2.0 {
                     self?.position = pos
                 }
             }
             .store(in: &cancellables)
    }

    private func handleTrackChange(_ track: SpotifyTrack?) {
        guard let track = track else { return }
        let newId = track.id?() ?? ""

        if newId != currentTrackID {
            self.currentTrackID = newId
            self.song = track.name ?? ""
            self.singer = track.artist ?? ""
            self.clearLyrics()

            // 判断是否为音乐内容（支持本地音乐和流媒体音乐，排除播客等）
            let spotifyUrl = track.spotifyUrl ?? ""
            // 音乐类型：spotify:track: 或 spotify:local:
            let isMusicTrack = spotifyUrl.hasPrefix("spotify:track:") || spotifyUrl.hasPrefix("spotify:local:")
            let hasValidInfo = !self.song.isEmpty

            // 只有在是音乐内容且有有效信息时才获取歌词
            if isMusicTrack && hasValidInfo {
                // Fetch new lyrics
                fetchLyrics()
            }

            // Send Notification
            NotificationService.shared.sendNotification(
                title: self.song,
                subtitle: self.singer,
                body: "",
                imageUrlString: nil // Could implement fetching artwork URL if available
            )
        }
    }

    func clearLyrics() {
        self.lyricLines.removeAll()
        self.lyricId = ""
        self.offset = 0
        self.position = 0.0
        self.activeIndex = -1
    }

    // MARK: - Loop

    enum TickOption {
        case immediate
        case scheduled(Double)
    }

    func scheduleNextTick(options: TickOption = .immediate) {
        timer?.cancel()

        guard isPlaying else { return }


        let delay: Double

        switch options {
        case .immediate:
            delay = 0
        case .scheduled(let seconds):
            delay = seconds
        }

        let t = DispatchSource.makeTimerSource(queue: updateQueue)
        t.schedule(deadline: .now() + delay, leeway: .milliseconds(20))
        t.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateLoop()
            }
        }
        timer = t
        t.resume()
    }

    @MainActor
    private func updateLoop() {
        guard isPlaying else { return }

        // Update Position
        // Ideally we use high-res timer or system clock delta,
        // using Spotify's polled position + local delta is common.
        let spotifyPos = spotifyService.getCurrentPosition()
        let localOffset = Double(offset) / 1000.0
        self.position = spotifyPos + localOffset
        // Refresh anchor so TimelineView-based views can extrapolate locally
        self.positionAnchor = PositionAnchor(position: self.position, date: Date())

        // Find current line active
        if let idx = lyricLines.firstIndex(where: { $0.beg <= position && position <= $0.end }) {
            self.activeIndex = idx
        }

        // Calculate next tick
        // 1. If inside a line, wait until end of line
        // 2. If between lines, wait until start of next line
        // 3. Min interval 0.1s

        var nextInterval: Double = 0.5

        if activeIndex >= 0 && activeIndex < lyricLines.count {
            let line = lyricLines[activeIndex]
            if !line.words.isEmpty {
                // Word-timing line: tick at word boundaries to keep the anchor fresh.
                // Visual smoothness is handled by TimelineView inside the active line view.
                // Cap at 0.5s so the anchor doesn't drift even between sparse word boundaries.
                if let nextWord = line.words.first(where: { $0.beg > position }) {
                    nextInterval = max(0.05, min(nextWord.beg - position, 0.5))
                } else {
                    nextInterval = max(0.05, min(line.end - position, 0.5))
                }
            } else {
                nextInterval = max(0.1, line.end - position)
            }
        } else if let nextLine = lyricLines.first(where: { $0.beg > position }) {
            let timeToStart = nextLine.beg - position
            nextInterval = max(0.1, timeToStart)
        }

        scheduleNextTick(options: .scheduled(nextInterval))
    }

    // MARK: - Actions

    func fetchLyrics(refresh: Bool = false, completion: (([LyricResponseItem]) -> Void)? = nil) {
        let req = LyricAPI(name: song, singer: singer, id: currentTrackID, refresh: refresh)
        lyricsService.fetchLyrics(apiData: req, host: self.host) { [weak self] items in
             DispatchQueue.main.async {
                 if let completion = completion {
                     completion(items)
                 } else {
                     // Default behavior: auto-load first if no explicit completion handler
                     if let first = items.first {
                         self?.loadLyrics(first)
                     }
                 }
             }
        } failure: { err in
            print("Failed to fetch lyrics: \(err)")
        }
    }

    func confirmLyrics(item: LyricResponseItem) {
        // Optimistically update
        loadLyrics(item)

        lyricsService.confirm(item: item, host: host) { msg in
             print("Confirmed: \(msg)")
        }
    }

    func updateOffset(_ newOffset: Int64) {
        self.offset = newOffset

        let api = OffsetAPI(sid: currentTrackID, lid: lyricId, offset: newOffset)
        lyricsService.offset(data: api, host: host) { msg in
            print("Offset updated: \(msg)")
        }
    }

    func loadLyrics(_ item: LyricResponseItem) {
        self.lyricLines = item.Lyrics()
        self.lyricId = item.lid
        self.offset = item.offset
    }
}
