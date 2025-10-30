import SwiftUI
import AppKit
import Combine

// 自定义窗口类，允许 borderless 窗口接收键盘事件
final class LyricsWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        // 处理 Command + W
        if event.modifierFlags.contains(.command) &&
           event.charactersIgnoringModifiers == "w" {
            self.close()
            return
        }
        super.keyDown(with: event)
    }
}

public final class LyricsHUD: NSViewController, NSWindowDelegate {
    var lyricsManager: LyricsManager
    private var hudWindow: LyricsWindow?
    private var cancellables: Set<AnyCancellable> = []
    private var closeButton: NSButton?
    private var trackingArea: NSTrackingArea?
    // 添加一个回调
    public var onWindowClosed: (() -> Void)?

    public init(lyricsManager: LyricsManager, onWindowClosed: (() -> Void)?) {
        self.lyricsManager = lyricsManager
        self.onWindowClosed = onWindowClosed
        super.init(nibName: nil, bundle: nil)
        setupWindow()
        observeLyricsManager()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // 清理 tracking area
        if let trackingArea = trackingArea, let button = closeButton {
            button.removeTrackingArea(trackingArea)
        }
        trackingArea = nil

        // 清理 cancellables
        cancellables.removeAll()

        // 清理窗口引用
        hudWindow?.delegate = nil
        hudWindow = nil
        closeButton = nil

        print("✅ LyricsHUD 已释放")
    }
    
    func observeLyricsManager() {
        lyricsManager.objectWillChange
            .sink { [weak self] _ in
              DispatchQueue.main.async {
                  guard let self = self, let window = self.hudWindow else {
                      return
                  }
                  guard let song = self.lyricsManager.song as String?,
                        let singer = self.lyricsManager.singer as String?,
                        !song.isEmpty, !singer.isEmpty
                  else {
                      window.title = ""
                      return
                  }
                  window.title = song + "-" + singer
              }
            }
            .store(in: &cancellables)
    }

    func setupWindow() {
        // 使用自定义窗口类
        let wd = LyricsWindow(
            contentRect: NSRect(x: 100, y: 100, width: 450, height: 800),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // 窗口基础设置
        wd.setFrameAutosaveName("Lyrics Window")
        wd.titlebarAppearsTransparent = true
        wd.isMovableByWindowBackground = true
        wd.level = .floating
        wd.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        wd.acceptsMouseMovedEvents = true  // 允许接收鼠标移动事件
        
        // 设置窗口背景透明和圆角
        wd.backgroundColor = NSColor.clear
        wd.isOpaque = false
        wd.hasShadow = true
        
        // 创建容器视图 - 这个视图将有圆角
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 10  // 适中的圆角
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderWidth = 0.5
        // containerView.layer?.borderColor = NSColor.separatorColor.cgColor  // 使用系统分隔线颜色
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        
        // 创建 NSVisualEffectView - 放在容器内
        let visualEffectView = NSVisualEffectView()
        // 使用毛玻璃效果
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.material = .underWindowBackground
        // 不设置固定的 appearance，让它跟随系统
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 10  // 与容器一致的圆角
        visualEffectView.layer?.masksToBounds = true
        
        // 添加额外的半透明背景层 - 使用系统颜色
        let backgroundView = NSView()
        backgroundView.wantsLayer = true
        // 使用系统窗口背景色，会自动适应深色/浅色模式

        backgroundView.layer?.cornerRadius = 10  // 与容器一致的圆角
        backgroundView.layer?.masksToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.layer?.backgroundColor = NSColor.clear.cgColor

        // 创建自定义关闭按钮 - 更小更柔和
        let button = NSButton(frame: NSRect(x: -10, y: -10, width: 5, height: 5))  // 从13改为10
        button.bezelStyle = .circular
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.image = nil
        button.wantsLayer = true
        // 使用更柔和的颜色和更低的透明度
        button.layer?.backgroundColor = NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.3).cgColor  // 灰色，低透明度
        button.layer?.cornerRadius = 5  // 从6.5改为5
        button.layer?.borderWidth = 0  // 移除边框
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(closeWindow)

        // 添加悬停效果
        let tracking = NSTrackingArea(
            rect: button.bounds,
            options: [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited],
//            options: [.activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: ["button": "close"]
        )
        button.addTrackingArea(tracking)

        // 保存引用以便后续清理
        closeButton = button
        trackingArea = tracking
        
        // 创建包含关闭按钮的容器视图
        let titleBarView = NSView()
        titleBarView.translatesAutoresizingMaskIntoConstraints = false
        titleBarView.wantsLayer = true
        
        // 创建一个包装视图来防止滚动条
        let hostingContainerView = NSView()
        hostingContainerView.translatesAutoresizingMaskIntoConstraints = false
        hostingContainerView.wantsLayer = true
        
        // 创建 NSHostingView - 不设置固定的颜色模式
        let hostingView = NSHostingView(rootView: DetailView(lyricsManager: lyricsManager)
            .background(Color.clear)
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置内容优先级，防止不必要的滚动
        hostingView.setContentHuggingPriority(.defaultLow, for: .vertical)
        hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // 设置窗口内容视图
        wd.contentView = containerView
        
        // 构建视图层级
        containerView.addSubview(visualEffectView)
        visualEffectView.addSubview(backgroundView)
        visualEffectView.addSubview(titleBarView)
        visualEffectView.addSubview(hostingContainerView)
        titleBarView.addSubview(button)
        hostingContainerView.addSubview(hostingView)
        
        // 设置容器视图约束
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        // 设置背景视图的约束
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])
        
        // 设置标题栏视图约束
        NSLayoutConstraint.activate([
            titleBarView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            titleBarView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            titleBarView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            titleBarView.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // 设置关闭按钮约束 - 左上角
        NSLayoutConstraint.activate([
            button.leftAnchor.constraint(equalTo: titleBarView.leftAnchor, constant: 10),
            button.topAnchor.constraint(equalTo: titleBarView.topAnchor, constant: 10),
            // closeButton.leadingAnchor.constraint(equalTo: titleBarView.leadingAnchor, constant: 10),  // 从18改为16
            // closeButton.centerYAnchor.constraint(equalTo: titleBarView.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 9),   // 从13改为10
            button.heightAnchor.constraint(equalToConstant: 9)   // 从13改为10
        ])

        // 设置 hostingView 在容器内的约束
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: hostingContainerView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: hostingContainerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: hostingContainerView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: hostingContainerView.bottomAnchor)
        ])
        
        // 设置容器的约束（原来 hostingView 的约束）
        NSLayoutConstraint.activate([
            hostingContainerView.topAnchor.constraint(equalTo: titleBarView.bottomAnchor, constant: -5),
            hostingContainerView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 28),
            hostingContainerView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -28),
            hostingContainerView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -28)
        ])

        // 设置窗口在关闭时不释放
        wd.isReleasedWhenClosed = false
        // 窗口代理
        wd.delegate = self
        // 保持对窗口的引用
        self.hudWindow = wd

        // 显示窗口
        showWindow()
    }
    
    // 关闭窗口方法
    @objc func closeWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.hudWindow?.close()
        }
    }
    
    // 鼠标悬停效果
    public override func mouseEntered(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo,
           let buttonType = userInfo["button"] as? String,
           buttonType == "close" {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
//                closeButton.animator().alphaValue = 1.0
//                closeButton.layer?.backgroundColor = NSColor(red: 1.0, green: 0.25, blue: 0.20, alpha: 1.0).cgColor
//                closeButton.layer?.transform = CATransform3DMakeScale(1.15, 1.15, 1.0)
            }
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo,
           let buttonType = userInfo["button"] as? String,
           buttonType == "close" {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
//                closeButton.animator().alphaValue = 0.9
//                closeButton.layer?.backgroundColor = NSColor(red: 0.95, green: 0.35, blue: 0.30, alpha: 0.9).cgColor
//                closeButton.layer?.transform = CATransform3DIdentity
            }
        }
    }
    
    public func showWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.hudWindow else { return }
            window.orderFront(nil)
            // 不再调用 makeKeyAndOrderFront，因为这会触发警告
            // 但窗口仍然可以接收键盘事件
        }
    }
    
    public func windowWillClose(_ notification: Notification) {
        // 清理 tracking area
        if let trackingArea = trackingArea, let button = closeButton {
            button.removeTrackingArea(trackingArea)
        }
        trackingArea = nil

        // 清理 cancellables
        cancellables.removeAll()

        // 清理窗口
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hudWindow?.delegate = nil
            self.hudWindow?.orderOut(nil)
            self.hudWindow = nil
            self.closeButton = nil
        }
        
        // 通知外部类
        self.onWindowClosed?()
    }
}
