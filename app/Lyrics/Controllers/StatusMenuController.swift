import AppKit
import Combine
import SwiftUI

final class StatusMenuController: NSObject {
    private var statusBarItem: NSStatusItem!
    private var lyricsViewModel: LyricsViewModel
    private var cancellables = Set<AnyCancellable>()
    private var hudWindow: LyricsHUD?
    private var popover: NSPopover?
    private var songInfoItem: NSMenuItem?
    private var selectionWindowController: LyricsSelectionWindowController?
    private var settingsWindowController: NSWindowController?

    init(viewModel: LyricsViewModel) {
        self.lyricsViewModel = viewModel
        super.init()
        setupStatusBar()
        setupBindings()
    }

    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem.button?.title = "..."
        statusBarItem.menu = buildMenu()
        updateStatusBarFont()
    }

    private func updateStatusBarFont() {
        let fontName = UserDefaults.standard.string(forKey: "lyricFontName") ?? "PingFang SC"

        // Try to get the font from the family name
        let fontDescriptor = NSFontDescriptor(fontAttributes: [.family: fontName])
        var font = NSFont(descriptor: fontDescriptor, size: 13)

        // Fallback to system font if custom font not available
        if font == nil {
            font = NSFont(name: fontName, size: 13)
        }

        statusBarItem.button?.font = font ?? NSFont.systemFont(ofSize: 13)

        // Force redraw the button to apply the new font
        statusBarItem.button?.needsDisplay = true
    }

    private func setupBindings() {
        // Update Status Bar Title based on active lyric
        lyricsViewModel.$activeIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                guard let self = self else { return }
                if index >= 0 && index < self.lyricsViewModel.lyricLines.count {
                    let text = self.lyricsViewModel.lyricLines[index].text
                    self.statusBarItem.button?.title = text
                } else if self.lyricsViewModel.isPlaying {
                     // 如果正在播放但没有歌词，显示播放内容标题
                     let song = self.lyricsViewModel.song
                     let singer = self.lyricsViewModel.singer
                     if !song.isEmpty && !singer.isEmpty {
                         self.statusBarItem.button?.title = "\(song) - \(singer)"
                     } else if !song.isEmpty {
                         self.statusBarItem.button?.title = song
                     } else {
                         self.statusBarItem.button?.title = "..."
                     }
                } else {
                    self.statusBarItem.button?.title = "..."
                }
            }
            .store(in: &cancellables)

        // Update Menu Item Title
        Publishers.CombineLatest(lyricsViewModel.$song, lyricsViewModel.$singer)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] song, singer in
                guard let self = self else { return }
                let title = self.formatSongTitle(song: song, singer: singer)
                self.songInfoItem?.title = "♪ \(title)"
            }
            .store(in: &cancellables)

        // Observe Font Changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarFont()
            }
            .store(in: &cancellables)
    }

    private func formatSongTitle(song: String, singer: String) -> String {
        if song.isEmpty { return "No Music" }
        if singer.isEmpty { return song }
        return "\(song) - \(singer)"
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // 1. Current Song Info
        let songTitle = formatSongTitle(song: lyricsViewModel.song, singer: lyricsViewModel.singer)
        let item = NSMenuItem(title: "♪ \(songTitle)", action: nil, keyEquivalent: "")
        item.tag = 100 // Tag for identification if needed, but we'll use a property
        self.songInfoItem = item
        menu.addItem(item)

        menu.addItem(NSMenuItem.separator())

        // 2. Open Choose Lyrics Window
        let refreshItem = NSMenuItem(title: "Choose Lyrics", action: #selector(choose), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        // 3. HUD
        let hudItem = NSMenuItem(title: "Lyrics Window", action: #selector(toggleHUD), keyEquivalent: "d")
        hudItem.target = self
        menu.addItem(hudItem)

        // 4. Offset
        let offsetItem = NSMenuItem(title: "Offset", action: #selector(offset), keyEquivalent: "")
        offsetItem.target = self
        menu.addItem(offsetItem)

        // 5. Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // 6. Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions

    @objc func toggleHUD() {
        if hudWindow == nil {
            hudWindow = LyricsHUD(lyricsManager: lyricsViewModel) { [weak self] in
                self?.hudWindow = nil
            }
        }
        hudWindow?.showWindow()
    }

    @objc func choose() {
        showSelectionWindow(items: [])
    }

    @objc func offset() {
        showPopover { [weak self] popover in
             guard let self = self else { return AnyView(EmptyView()) }
             // Note: OffsetView needs customization to work with ViewModel if not already
            return AnyView(OffsetView(lyricsManager: self.lyricsViewModel) { offset in
                 // Logic to save offset
                 print("New offset: \(offset)")
                 self.lyricsViewModel.updateOffset(offset)
             })
        }
    }

    @objc func openSettings() {
        if let settingsWindowController = settingsWindowController {
            settingsWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(lyricsViewModel: lyricsViewModel)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Lyrics Settings"
        window.setContentSize(NSSize(width: 400, height: 300))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()

        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindowController = controller
    }

    // MARK: - Popover Helpers

    private func showSelectionWindow(items: [LyricResponseItem]) {
        // Close existing if open
        if let existing = selectionWindowController {
            existing.close()
            selectionWindowController = nil
        }

        let initialTitle = lyricsViewModel.song
        let initialSinger = lyricsViewModel.singer

        // Create and show window
        selectionWindowController = LyricsSelectionWindowController(
            lyricsManager: lyricsViewModel,
            items: items,
            initialTitle: initialTitle,
            initialSinger: initialSinger,
            onSelect: { [weak self] selectedItem in
                DispatchQueue.main.async {
                    self?.lyricsViewModel.confirmLyrics(item: selectedItem)
                    self?.selectionWindowController?.close()
                    self?.selectionWindowController = nil
                }
            },
            onSearch: { [weak self] title, singer, completion in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    // Update ViewModel
                    self.lyricsViewModel.song = title
                    self.lyricsViewModel.singer = singer

                    // Fetch new results
                    self.lyricsViewModel.fetchLyrics(refresh: true) { newItems in
                        DispatchQueue.main.async {
                            // Call completion to update the view, DO NOT close window
                            completion(newItems)
                        }
                    }
                }
            }
        )
        selectionWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showPopover<Content: View>(viewBuilder: @escaping (NSPopover) -> Content) {
        // Close existing
        popover?.performClose(nil)

        guard let button = statusBarItem.button else { return }

        let newPopover = NSPopover()
        newPopover.behavior = .transient
        let hostedView = viewBuilder(newPopover)
        newPopover.contentViewController = NSHostingController(rootView: hostedView)

        newPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = newPopover
    }
}
