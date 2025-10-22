//
//  LyricsMenuBar.swift
//

import AppKit
import Foundation
import ScriptingBridge
import SwiftUI
import UserNotifications

// MARK: - LyricsManager

public final class LyricsManager: ObservableObject {
    // 歌曲信息
    @Published var song: String = ""
    @Published var singer: String = ""
    @Published var currentTrackID: String = ""
    
    // 歌词相关
    @Published var lyricLines: [LyricLine] = []
    @Published var lyricId: String = ""
    @Published var offset: Int64 = 0
    
    // 播放位置 - 使用 @Published 需要谨慎，频繁更新会导致内存压力
    @Published var position: Double = 0.0
    
    // API 配置
    @Published var host: String {
        didSet {
            UserDefaults.standard.set(host, forKey: "api_host")
        }
    }

    init() {
        self.host = UserDefaults.standard.string(forKey: "api_host")
            ?? "https://127.0.0.1:8331"
    }
    
    // 清理内存
    func clearLyrics() {
        lyricLines.removeAll()
        lyricId = ""
        offset = 0
        position = 0.0
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: Properties
    
    static private(set) var shared: AppDelegate!
    
    // UI 组件
    private var statusBarItem: NSStatusItem?
    var hudWindow: LyricsHUD?
    private var currentPopover: NSPopover?
    
    // 核心管理器
    var lyricsManager = LyricsManager()
    
    // 计时器 - 使用单一队列而不是每次创建新的
    private var updateQueue = DispatchQueue(
        label: "com.lyrics.updateQueue",
        qos: .userInteractive
    )
    private var timer: DispatchSourceTimer?
    private var playbackObserver: NSObjectProtocol?
    
    // 上一次的 track ID，用于检测切换
    private var lastTrackID: String = ""
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        required()
        
        setupStatusBar()
        setupTimers()
    }
    
    deinit {
        // 清理所有计时器
        timer?.cancel()
        timer = nil
        // 移除观察者
        if let observer = playbackObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }

        // 关闭 hudWindow
        if let hudWindow = hudWindow {
            hudWindow.closeWindow()
        }
        hudWindow = nil

        // 关闭 popover
        currentPopover?.performClose(nil)
        currentPopover = nil

        print("✅ AppDelegate 已释放")
    }
    
    // MARK: - Setup Methods
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        statusBarItem?.menu = NSMenu()
        statusBarItem?.menu?.addItem(
            NSMenuItem(
                title: "Set Host",
                action: #selector(setHost),
                keyEquivalent: ""
            )
        )
        statusBarItem?.menu?.addItem(
            NSMenuItem(
                title: "Quit",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
    }
    
    private func setupTimers() {
        setupPlaybackObserver()
        scheduleNextTick()
    }
    
    // MARK: - Timer Setup
    
    /// 监听 Spotify 播放状态变化
    func setupPlaybackObserver() {
        playbackObserver = DistributedNotificationCenter.default()
            .addObserver(
                forName: Notification.Name("com.spotify.client.PlaybackStateChanged"),
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let self else { return }
                
                let info = note.userInfo as? [String: Any]
                let state = (info?["Player State"] as? String) ?? ""
                let trackId = info?["Track ID"] as? String
                let name = info?["Name"] as? String
                let artist = info?["Artist"] as? String
                let position = info?["Position"] as? Double

                // 收到通知时立即校正位置
                if let position {
                    self.lyricsManager.position = position
                }

                // 播放/暂停状态管理
                if state.lowercased() == "playing" {
                    self.scheduleNextTick(minInterval: 0.1)
                } else {
                    self.scheduleNextTick(minInterval: 3.0)
                }

                // 歌曲切换检测
                if let trackId, trackId != self.lastTrackID {
                    self.lastTrackID = trackId
                    self.lyricsManager.currentTrackID = trackId
                    self.lyricsManager.song = name ?? ""
                    self.lyricsManager.singer = artist ?? ""
                    self.lyricsManager.clearLyrics()
                    self.lyricsManager.position = position ?? 0
                    self.updateBarTitle(message: "...")
                    
                    self.fetchLyrics(
                        name: name,
                        singer: artist,
                        id: trackId,
                        refresh: false
                    )
                    sendNotification(
                        title: self.lyricsManager.song,
                        subtitle: self.lyricsManager.singer,
                        body: "",
                        imageUrlString: nil
                    )
                }
            }
    }
    
    // MARK: - Core Update Logic
    
    /// 主更新逻辑
    func update() {
        guard Provider.shared.playing() else {
            DispatchQueue.main.async { [weak self] in
                self?.updateBarTitle(message: "...")
            }
            scheduleNextTick(minInterval: 3.0)
            return
        }
        
        // 检查歌曲切换
        if let track = Provider.shared.next(
            currentTrackID: lyricsManager.currentTrackID
        ) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.updateBarTitle(message: "...")
                self.lyricsManager.clearLyrics()
                self.lyricsManager.song = track.name ?? ""
                self.lyricsManager.singer = track.artist ?? ""
                self.lyricsManager.currentTrackID = track.id?() ?? ""
                self.currentPopover?.performClose(nil)
                self.currentPopover = nil
                self.lastTrackID = self.lyricsManager.currentTrackID
            }

            fetchLyrics(
                name: track.name,
                singer: track.artist,
                id: track.id?(),
                refresh: false
            )
            sendNotification(
                title: track.name,
                subtitle: track.artist,
                body: "",
                imageUrlString: nil
            )
        }

        // ⚠️ 修复：计算当前播放位置（括号很重要！）
        let rawPosition = Provider.shared.spotify?.playerPosition ?? 0.0
        let offsetSeconds = Double(lyricsManager.offset) / 1000.0
        let localPosition = rawPosition + offsetSeconds

        // 找到当前歌词行
        if let lyricLine = lyricsManager.lyricLines.last(where: {
            $0.beg <= localPosition && localPosition <= $0.end
        }), !lyricLine.text.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.lyricsManager.position = localPosition
                self?.updateBarTitle(message: lyricLine.text)
            }
        }
        
        print("🎵 Current Position: \(localPosition)")

        // 按下一句边界精确调度
        scheduleNextTick(currentPosition: localPosition)
    }
    
    /// 按下一句歌词边界调度更新 - 优化版
    func scheduleNextTick(currentPosition: Double? = nil, minInterval: Double = 0.1) {
        // 取消之前的 timer
        timer?.cancel()
        
        let position: Double
        if let currentPosition {
            position = currentPosition
        } else {
            let localOffset = Double(lyricsManager.offset) / 1000.0
            position = lyricsManager.position + localOffset
        }

        // 计算下一次更新的时间
        var nextDelta: Double = 1.0
        if !lyricsManager.lyricLines.isEmpty {
            let lines = lyricsManager.lyricLines

            // 找到当前正在显示的行
            let currentIndex = lines.firstIndex { line in
                line.beg <= position && position <= line.end
            }

            if let idx = currentIndex {
                // 🟢 当前在某一句歌词中
                let cur = lines[idx]
                let toEnd = cur.end - position
                
                print(" ✅ 在第 \(idx) 行歌词中 \(String(format: "%.3f", cur.beg)) - \(String(format: "%.3f", cur.end)) | \(cur.text)")
                if idx + 1 < lines.count {
                    let toNextBeg = lines[idx + 1].beg - position
                    nextDelta = max(min(toEnd, toNextBeg), minInterval)
                    print("   到下一行: \(String(format: "%.3f", toNextBeg))s")
                } else {
                    nextDelta = max(toEnd, minInterval)
                    print("   ⚠️ 这是最后一行")
                }
            } else {
                if let next = lines.first(where: { $0.beg > position }) {
                    let distance = next.beg - position
                    nextDelta = max(distance, minInterval)
                    print("   找到下一行，距离: \(String(format: "%.3f", distance))s    下一行内容: \(next.text)")
                } else {
                    // 已经播放完所有歌词
                    nextDelta = 1.0
                    print("   ❌ 没有更多歌词了")
                }
            }
        } else {
            print("⚠️ 歌词列表为空")
        }
        
        print("⏱️  nextDelta = \(String(format: "%.3f", nextDelta))s")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

        // 使用复用的队列而不是每次创建新的
        let t = DispatchSource.makeTimerSource(queue: updateQueue)
        t.schedule(deadline: .now() + nextDelta, leeway: .milliseconds(50))
        t.schedule(deadline: .now() + nextDelta, leeway: .milliseconds(50))
        t.setEventHandler { [weak self] in
            self?.update()
        }
        timer = t
        t.resume()
    }
    
    // MARK: - Lyrics Management
    
    private func fetchLyrics(name: String?, singer: String?, id: String?, refresh: Bool) {
        LyricAPI(
            name: name,
            singer: singer,
            id: id,
            refresh: refresh
        )
        .lyrics(
            host: lyricsManager.host,
            success: { [weak self] item in
                self?.createMenuWithItems(items: item, i: 0)
            }
        ) { [weak self] message in
            DispatchQueue.main.async {
                self?.updateBarTitle(message: message)
            }
        }
    }
    
    func createMenuWithItems(items: [LyricResponseItem], i: Int?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let menu = NSMenu()
            
            for (index, item) in items.enumerated() {
                if i != nil && index == i {
                    self.lyricsManager.lyricLines = item.Lyrics()
                    self.lyricsManager.offset = item.offset
                    self.lyricsManager.lyricId = item.lid
                    self.lyricsManager.singer = item.singer
                    self.lyricsManager.song = item.name
                    let menuItem = NSMenuItem(
                        title: "♪ \(item.name) - \(item.singer) | \(item.type)",
                        action: nil,
                        keyEquivalent: ""
                    )
                    menu.addItem(menuItem)
                } else {
                    let menuItem = NSMenuItem(
                        title: "   \(item.name) - \(item.singer) | \(item.type)",
                        action: #selector(self.cofirm),
                        keyEquivalent: ""
                    )
                    menuItem.target = self
                    menuItem.representedObject = items
                    menu.addItem(menuItem)
                }
            }
            
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Refresh", action: #selector(self.refresh(_:)), keyEquivalent: "r"))
            menu.addItem(NSMenuItem(title: "Lyrics Window", action: #selector(self.hud), keyEquivalent: "d"))
            menu.addItem(NSMenuItem(title: "Research", action: #selector(self.search), keyEquivalent: "f"))
            menu.addItem(NSMenuItem(title: "Offset", action: #selector(self.offset), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Set Host", action: #selector(self.setHost), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            
            self.statusBarItem?.menu = menu
        }
    }
    
    // MARK: - Menu Actions
    
    @objc func cofirm(sender: NSMenuItem) {
        guard let itemList = sender.representedObject as? [LyricResponseItem],
            let index = sender.menu?.index(of: sender)
        else {
            updateBarTitle(message: "☹️Please Refresh")
            return
        }
        
        createMenuWithItems(items: itemList, i: index)
        ConfirmAPI(item: itemList[index])
            .confirm(host: lyricsManager.host) { [weak self] message in
                DispatchQueue.main.async {
                    self?.lyricsManager.clearLyrics()
                    self?.updateBarTitle(message: message)
                }
            }
    }
    
    @objc func refresh(_ sender: Any?) {
        _refresh(r: true)
    }
    
    func _refresh(r: Bool) {
        if let track = Provider.shared.spotify?.currentTrack {
            DispatchQueue.main.async { [weak self] in
                self?.lyricsManager.clearLyrics()
                self?.updateBarTitle(message: "...")
            }
            
            fetchLyrics(
                name: track.name,
                singer: track.artist,
                id: track.id?(),
                refresh: r
            )
        }
    }
    
    @objc func search() {
        // 先关闭之前的 popover
        currentPopover?.performClose(nil)
        currentPopover = nil
        
        presentPopover { [weak self] popover in
            let name = self?.lyricsManager.song ?? ""
            let singer = self?.lyricsManager.singer ?? ""
            return SearchView(
                onSubmit: { [weak self] newName, newSinger in
                    popover.performClose(nil)
                    guard let self = self else { return }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.fetchLyrics(
                            name: newName,
                            singer: newSinger,
                            id: self.lyricsManager.currentTrackID,
                            refresh: true
                        )
                    }
                },
                name: name,
                singer: singer
            )
        }
    }
    
    @objc func offset() {
        currentPopover?.performClose(nil)
        currentPopover = nil
        
        presentPopover { [weak self] popover in
            popover.performClose(nil)
            let contentView = OffsetView(lyricsManager: self!.lyricsManager
            ) { [weak self] offset in
                guard let self = self else { return }
                OffsetAPI(
                    sid: self.lyricsManager.currentTrackID,
                    lid: self.lyricsManager.lyricId,
                    offset: offset
                )
                .offset(host: self.lyricsManager.host) { [weak self] message in
                        self?.updateBarTitle(message: message)
                }
            }
            return contentView
        }
    }
    
    @objc func hud() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 如果已经有窗口,先关闭
            if let existingWindow = self.hudWindow {
                existingWindow.closeWindow()
                self.hudWindow = nil
            }

            NSApplication.shared.activate(ignoringOtherApps: true)
            self.hudWindow = LyricsHUD(lyricsManager: self.lyricsManager)
            self.hudWindow?.showWindow()
        }
    }
    
    @objc func setHost() {
        currentPopover?.performClose(nil)
        currentPopover = nil
        
        presentPopover { [weak self] _ in
            guard let self else { return AnyView(EmptyView()) }
            return AnyView(SetHostView(host: self.lyricsManager.host) { host in
                self.lyricsManager.host = host
            })
        }
    }
    
    // MARK: - Helper Methods
    
    func updateBarTitle(message: String) {
        statusBarItem?.button?.title = message
    }
    
    private func presentPopover<V: View>(size: NSSize? = nil, makeView: (NSPopover) -> V) {
        guard let button = statusBarItem?.button else { return }
        let popover = NSPopover()
        if let size { popover.contentSize = size }
        popover.behavior = .transient
        
        let view = makeView(popover)
        popover.contentViewController = NSHostingController(rootView: view)
        
        // 关闭旧 popover
        currentPopover?.performClose(nil)
        currentPopover = popover
        
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
    }
}
