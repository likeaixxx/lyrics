import SwiftUI
import ScriptingBridge
import Foundation
import UserNotifications

@main
struct LyricsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("Settings not available.")
        }
    }
}

struct LyricLine {
    let time: TimeInterval
    let text: String
}

struct LyricForm: Codable {
    let name: String
    let singer: String?
    let id: String?
    let refresh: Bool?
}

struct LyricResponseBody: Codable {
    let code: Int
    let message: String?
    let data: [LyricResponseItem]?
}

let QQ    = "QQ Music"
let KuGou = "KuGou Music"
let NetEase = "NetEase Music"

struct LyricResponseItem: Codable {
    let singer: String
    let name: String
    let sid: String
    let lid: String
    let lyrics: String
    let type: String
}

// Singleton pattern for Spotify Script
class SpotifyScriptProvider {
    static let shared = SpotifyScriptProvider()
    var spotifyApp: SpotifyApplication? = SBApplication(bundleIdentifier: "com.spotify.client")
}

extension String {
    func decodeHTML() -> String {
        return self
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

func parseLyricsLine(lyricsLine: String) -> LyricLine? {
    let components = lyricsLine.components(separatedBy: "]")
    if components.count > 1, let timeString = components.first, let text = components.last {
        let cleanTime = timeString.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let timeParts = cleanTime.components(separatedBy: ":")
        if timeParts.count == 2 {
            let minutePart = timeParts[0]
            let secondParts = timeParts[1].components(separatedBy: ".")
            if secondParts.count == 2,
               let minutes = Int(minutePart),
               let seconds = Int(secondParts[0]),
               let milliseconds = Int(secondParts[1]) {
                
                let totalSeconds = TimeInterval(minutes * 60 + seconds) + TimeInterval(milliseconds) / 1000.0
                let line = text.decodeHTML()
                if !line.isEmpty {
                    return LyricLine(time: totalSeconds, text: "♪ " + line)
                }
            }
        }
    }
    return nil
}

func parseLyrics(_ lyrics: [String]) -> [LyricLine] {
    return lyrics.compactMap { line in
        return parseLyricsLine(lyricsLine: line)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var popover: NSPopover?
    
    var lyricLines: [LyricLine] = []
    var currentTrackID: String?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    // 已授权，可以排定或发送通知
                } else {
                    self.requestNotificationPermission()
                }
            }
        }
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(forceRefresh), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        self.statusBarItem?.menu = menu
        popover = NSPopover()
        popover?.behavior = .transient
        setupPeriodicLyricUpdate()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("通知权限已授权")
            } else if let error = error {
                print("请求通知权限出错: \(error)")
            }
        }
    }
    
    func setupPeriodicLyricUpdate() {
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            self?.checkForMusicChangeAndUpdateLyrics(refresh: false)
        }
    }
    
    func updateLyricsOnStatusBar() {
        guard let spotifyApp = SpotifyScriptProvider.shared.spotifyApp,
              spotifyApp.playerState == .playing,
              let currentTrackPosition = spotifyApp.playerPosition else {
            statusBarItem?.button?.title = "..."
            return
        }
        
        self.currentTrackID = spotifyApp.currentTrack?.id?()
        
        if let lyricLine = lyricLines.last(where:  {$0.time <= currentTrackPosition}) {
            if lyricLine.text != ""{
                statusBarItem?.button?.title = lyricLine.text
            }
        }
    }
    
    func checkForMusicChangeAndUpdateLyrics(refresh: Bool) {
        guard let spotifyApp = SpotifyScriptProvider.shared.spotifyApp,
              spotifyApp.playerState == .playing,
              let currentTrack = spotifyApp.currentTrack,
              let _ = currentTrack.name else {
            statusBarItem?.button?.title = "..."
            return
        }
        
        if let trackId = currentTrack.id?(), trackId != self.currentTrackID || refresh {
            self.currentTrackID = trackId
            self.updateLyricsForCurrentSong(currentTrack: currentTrack, refresh: refresh)
            if !refresh {
                self.eventPush(currentTrack: currentTrack)
            }
        }
        self.updateLyricsOnStatusBar()
    }
    
    fileprivate func searchMusic(_ form: LyricForm) {
        guard let requestBody = try? JSONEncoder().encode(form) else {
            print("Error: Unable to encode lyricForm")
            return
        }
        
        if let url = URL(string: "http://localhost:8080/api/v1/lyrics") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = requestBody
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let session = URLSession.shared
            let task = session.dataTask(with: request) { [weak self] data, response, error in
                if error != nil {
                    self?.updateFailed(message: "Network Error")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let data = data else {
                    print("Server error or invalid response data")
                    self?.updateFailed(message: "Network Error")
                    return
                }
                
                do {
                    let lyricResponse = try JSONDecoder().decode(LyricResponseBody.self, from: data)
                    if let itemList = lyricResponse.data {
                        DispatchQueue.main.async {
                            self?.createMenuWithItems(items: itemList)
                        }
                    } else {
                        self?.updateFailed(message: "Nothing Found")
                    }
                } catch {
                    print("Failed to decode data: \(error)")
                }
            }
            task.resume()
        }
    }
    
    func updateLyricsForCurrentSong(currentTrack: SpotifyTrack, refresh: Bool) {
        guard let trackName = currentTrack.name, let trackArtist = currentTrack.artist else {
            print("Error: Track name and artist must not be nil")
            return
        }
        self.searchMusic(LyricForm(name: trackName, singer: trackArtist, id: currentTrack.id?(), refresh: refresh))
    }
    
    func createMenuWithItems(items: [LyricResponseItem]) {
        let menu = NSMenu()
        for (index, item) in items.enumerated() {
            if index == 0 {
                reload(data: item)
            }
            let menuItem = NSMenuItem(title: "\(item.name) - \(item.singer) | \(item.type)", action: #selector(click), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = items
            menu.addItem(menuItem)
        }
        menu.addItem(NSMenuItem.separator())  // Optional separator
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(forceRefresh), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Research", action: #selector(customerInputSearch), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Clean Waning", action: #selector(clean), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        self.statusBarItem?.menu = menu
    }
    
    @objc func click(sender: NSMenuItem) {
        if let itemList = sender.representedObject as? [LyricResponseItem],
           let index = sender.menu?.index(of: sender) {
            self.reload(data: itemList[index])
            
            guard let requestBody = try? JSONEncoder().encode(itemList[index]) else {
                print("Error: Unable to encode lyricForm")
                return
            }
            if let url = URL(string: "http://localhost:8080/api/v1/lyrics/confirm") {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = requestBody
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let session = URLSession.shared
                let task = session.dataTask(with: request) { [weak self] data, response, error in
                    if error != nil {
                        self?.updateFailed(message: "Network Error")
                        return
                    }
                }
                task.resume()
            }
        }
    }
    
    @objc func forceRefresh() {
        self.checkForMusicChangeAndUpdateLyrics(refresh: true)
    }
    
    @objc func clean() {
        self.lyricLines = []
        self.statusBarItem?.button?.title = "☹️..."
    }
    
    func reload(data: LyricResponseItem) {
        if data.type == QQ || data.type == NetEase {
            if let lyricsData = Data(base64Encoded: data.lyrics) {
                if let lyrics = String(data: lyricsData, encoding: .utf8) {
                    let lyricsLines = lyrics.split(separator: "\n").map(String.init)
                    DispatchQueue.main.async {
                        self.lyricLines = parseLyrics(lyricsLines)
                    }
                } else {
                    print("Failed to decode lyrics from data.")
                }
            }
        }
        
        if data.type == KuGou {
            if let lyricsData = decryptKugouKrc(data.lyrics.data(using: .ascii)!) {
                let lyricsLines = lyricsData.split(separator: "\n").map(String.init)
                lyricsLines.forEach { line in
                    print("\(line)")
                }
                DispatchQueue.main.async {
                    self.lyricLines = parseLyrics(lyricsLines)
                }
            }
        }
    }
    
    func updateFailed(message: String) {
        DispatchQueue.main.async {
            self.statusBarItem?.button?.title = "☹️" + message
        }
    }
    
    func eventPush(currentTrack: SpotifyTrack) {
        if let name = currentTrack.name, !name.isEmpty {
            self.sendNotification(title: name, subtitle: currentTrack.artist ?? "", body: "")
        }
    }
    
    func sendNotification(title: String, subtitle: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = UNNotificationSound.default
        
        // 通知触发器
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // 创建一个通知请求
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        // 将请求添加到通知中心
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知发送失败: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func customerInputSearch() {
        guard let popover = popover, let statusItem = self.statusBarItem else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let contentView = PopupView { name, singer in
                // Handle the submitted text here
                popover.performClose(nil)
                self.searchMusic(LyricForm(name: name, singer: singer, id: self.currentTrackID, refresh: true))
            }
            popover.contentViewController = NSHostingController(rootView: contentView)
            popover.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: .minY)
        }
    }
}

struct PopupView: View {
    var onSubmit: (String, String) -> Void
    @State private var name: String = ""
    @State private var singer: String = ""
    
    var body: some View {
        VStack {
            Text("Research")
            TextField("Song Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            TextField("Singer", text: $singer)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: {
                onSubmit(name, singer)
            }) {
                Text("Submit")
//                    .background(Color.blue)
                    .foregroundColor(.blue)
            }
        }
        .frame(width: 150, height: 100)
        .padding()
    }
}
