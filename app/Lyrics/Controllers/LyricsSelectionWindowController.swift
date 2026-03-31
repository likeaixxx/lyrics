import AppKit
import SwiftUI

final class LyricsSelectionWindowController: NSWindowController {

    // Updated init to include search callback with completion handler
    convenience init(lyricsManager: LyricsViewModel,
                     items: [LyricResponseItem],
                     initialTitle: String,
                     initialSinger: String,
                     onSelect: @escaping (LyricResponseItem) -> Void,
                     onSearch: @escaping (String, String, @escaping ([LyricResponseItem]) -> Void) -> Void) {

        // Create borderless window using custom subclass
        let window = SelectionWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 550),
            styleMask: [.borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("Lyrics Selection Window")
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false

        // Setup Visual Effect View (Frosted Glass)
        let visualEffectView = NSVisualEffectView()
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16
        visualEffectView.layer?.cornerCurve = .continuous
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 0.5
        visualEffectView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.2).cgColor

        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Host SwiftUI logic
        let selectionView = LyricsSelectionView(
            lyricsManager: lyricsManager,
            items: items,
            initialTitle: initialTitle,
            initialSinger: initialSinger,
            onSelect: { item in
                onSelect(item)
                NSApp.keyWindow?.close()
            },
            onSearch: { title, singer, completion in
                onSearch(title, singer, completion)
            }
        )
        .background(Color.clear)
        .edgesIgnoringSafeArea(.all)

        let hostingController = NSHostingController(rootView: selectionView)
        let hostingView = hostingController.view
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Assemble View Hierarchy
        window.contentView = containerView
        containerView.addSubview(visualEffectView)
        visualEffectView.addSubview(hostingView)

        // Layout
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])

        self.init(window: window)
    }
}

// Private subclass to ensure key events work for borderless window
private final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
