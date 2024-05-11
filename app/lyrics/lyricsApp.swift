import SwiftUI
import ScriptingBridge
import Foundation

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
    let data: [LyricResponseItem]
}

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

func parseLyricsLine(lyricsLine: String) -> LyricLine {
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
                return LyricLine(time: totalSeconds, text: "♪" + text.decodeHTML())
            }
        }
    }
    return LyricLine(time: 0.0, text: "")
}

func parseLyrics(_ lyrics: [String]) -> [LyricLine] {
    return lyrics.compactMap { line in
        return parseLyricsLine(lyricsLine: line)
    }
    .filter{ line in
        return line.text != "♪"
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var lyricLines: [LyricLine] = []
    var currentTrackID: String?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(forceRefresh), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        self.statusBarItem?.menu = menu
        
        setupPeriodicLyricUpdate()
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
        }
        self.updateLyricsOnStatusBar()
    }
    
    func updateLyricsForCurrentSong(currentTrack: SpotifyTrack, refresh: Bool) {
        guard let trackName = currentTrack.name, let trackArtist = currentTrack.artist else {
            print("Error: Track name and artist must not be nil")
            return
        }
        
        let lyricForm = LyricForm(name: trackName, singer: trackArtist, id: currentTrack.id?(), refresh: refresh)
        guard let requestBody = try? JSONEncoder().encode(lyricForm) else {
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
                    return
                }
                
                do {
                    let lyricResponse = try JSONDecoder().decode(LyricResponseBody.self, from: data)
                    let itemList = lyricResponse.data
                    DispatchQueue.main.async {
                        self?.createMenuWithItems(items: itemList)
                    }
                } catch {
                    print("Failed to decode data: \(error)")
                }
            }
            task.resume()
        }
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
    
    func reload(data: LyricResponseItem) {
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
    
    func updateFailed(message: String) {
        DispatchQueue.main.async {
            self.statusBarItem?.button?.title = "☹️" + message
        }
    }
}
