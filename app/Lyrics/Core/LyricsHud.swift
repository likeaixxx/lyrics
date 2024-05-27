import SwiftUI
import AppKit
import Cocoa
import Combine

public class LyricsHUD: NSViewController, NSWindowDelegate {
    var lyricsManager: LyricsManager
    var hudWindow: NSWindow!
    var cancellables: Set<AnyCancellable> = []

    public init(lyricsManager: LyricsManager) {
        self.lyricsManager = lyricsManager
        super.init(nibName: nil, bundle: nil)
        setupWindow()
        observeLyricsManager()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
    
    func observeLyricsManager() {
        lyricsManager.objectWillChange
            .sink { [weak self] _ in
              DispatchQueue.main.async {
                  if self?.hudWindow == nil {
                      return
                  }
                  guard let song = self?.lyricsManager.song,
                        let singer = self?.lyricsManager.singer
                  else {
                      self?.hudWindow.title = ""
                      return
                  }
                  self?.hudWindow.title = song + "-" + singer
              }
            }
            .store(in: &cancellables)
    }

    func setupWindow() {
        // 创建带有标题栏的窗口
        let wd = NSWindow(
            contentRect: NSRect(x: 70, y: 50, width: 400, height: 1000),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        wd.setFrameAutosaveName("Lyrics Window")
        wd.styleMask.insert(.borderless)
        wd.titlebarAppearsTransparent = true
        wd.level = .floating

        // ---- 以下都是为了隐藏滚动条恶心的白底色
        // 创建 NSVisualEffectView
        let visualEffectView = NSVisualEffectView()
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.material = .underWindowBackground
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        // 创建 NSHostingView 并将其添加到 NSVisualEffectView 中
        let hostingView = NSHostingView(rootView: DetailView(lyricsManager: lyricsManager))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(hostingView)

        // 将 NSVisualEffectView 添加到窗口的 contentView 中
        wd.contentView = visualEffectView

        // 设置 NSHostingView 的约束
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])

        // 设置窗口在关闭时不释放
        wd.isReleasedWhenClosed = false
        // 窗口代理
        wd.delegate = self
        // 保持对窗口的引用,以防止它被释放
        self.hudWindow = wd

        // 在设置完窗口后立即显示窗口
        showWindow()
    }
    
    public func showWindow() {
        DispatchQueue.main.async { [weak self] in
           self?.hudWindow.makeKeyAndOrderFront(nil) // Ensure window is shown on top
        }
    }
    
    public func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.hudWindow.orderOut(nil)
            self?.hudWindow = nil
        }
    }
}



