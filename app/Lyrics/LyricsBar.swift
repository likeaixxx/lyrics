//
//  LyricsMenuBar.swift
//  lyrics-v3
//
//  Created by 陈爱全 on 2024/5/15.
//
import Foundation
import AppKit
import SwiftUI
import ScriptingBridge
import UserNotifications

public class LyricsManager: ObservableObject {
    @Published var song: String = ""
    @Published var singer: String = ""
    @Published var lyricLines: [LyricLine] = []
    @Published var currentTrackID: String = ""
    @Published var position: Double = 0.0
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var lyricsManager = LyricsManager()
    var hudWindow: LyricsHUD?

    func applicationDidFinishLaunching(_ notification: Notification) {
        required()
        
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusBarItem?.menu = NSMenu()
        self.statusBarItem?.menu?.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    func update() {
        guard Provider.shared.playing() else {
            updateBarTitle(message: "...")
            return
        }
        // 判断是不是下一首了
        if let track = Provider.shared.next(currentTrackID: self.lyricsManager.currentTrackID) {
            self.lyricsManager.lyricLines = []
            self.lyricsManager.song = track.name ?? ""
            self.lyricsManager.singer = track.artist ?? ""
            
            updateBarTitle(message: "...")
            self.lyricsManager.currentTrackID = track.id?() ?? ""
            sendNotification(title: track.name, subtitle: track.artist, body: "")
            // 更新歌词
            LyricAPI(name: track.name, singer: track.artist, id: self.lyricsManager.currentTrackID, refresh: false)
                .lyrics(success: { item in
                    self.createMenuWithItems(items: item, i: 0)
                }) { message in
                    self.updateBarTitle(message: message)
                }
        }
        
        // 下一句
        if  let position = Provider.shared.spotify?.playerPosition {
            self.lyricsManager.position = position
            
            if let lyricLine = self.lyricsManager.lyricLines.last(where:  {$0.beg <= position}) {
                if lyricLine.text != "" {
                    updateBarTitle(message: "♪ " + lyricLine.text)
                }
            } else if !lyricsManager.lyricLines.isEmpty {
                let line = lyricsManager.lyricLines[0]
                if line.text != ""{
                    updateBarTitle(message: "♪ " + line.text)
                }
            }
        }
    }
    
    func createMenuWithItems(items: [LyricResponseItem], i: Int?) {
        DispatchQueue.main.async { [self] in
            let menu = NSMenu()
            for (index, item) in items.enumerated() {
                if i != nil && index == i {
                    self.lyricsManager.lyricLines = item.parseLyrics()
                    let menuItem = NSMenuItem(title: "♪ \(item.name) - \(item.singer) | \(item.type)", action: nil, keyEquivalent: "")
                    menu.addItem(menuItem)
                } else {
                    let menuItem = NSMenuItem(title: "   \(item.name) - \(item.singer) | \(item.type)", action: #selector(cofirm), keyEquivalent: "")
                    menuItem.target = self
                    menuItem.representedObject = items
                    menu.addItem(menuItem)
                }
            }
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r"))
            menu.addItem(NSMenuItem(title: "Lyrics Detail", action: #selector(detail), keyEquivalent: "d"))
            menu.addItem(NSMenuItem(title: "Lyrics Window", action: #selector(hud), keyEquivalent: "o"))
            menu.addItem(NSMenuItem(title: "Report", action: #selector(clean), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Research", action: #selector(search), keyEquivalent: "f"))
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            self.statusBarItem?.menu = menu
        }
    }
    
    @objc func cofirm(sender: NSMenuItem) {
        guard let itemList = sender.representedObject as? [LyricResponseItem],
              let index = sender.menu?.index(of: sender) else {
            updateBarTitle(message: "☹️Please Refresh")
            return
        }
        self.createMenuWithItems(items: itemList, i: index)
        ConfirmAPI(item: itemList[index])
            .confirm { message in
                self.lyricsManager.lyricLines = []
                self.updateBarTitle(message: message)
            }
    }
    
    @objc func clean() {
        self.lyricsManager.lyricLines = []
        updateBarTitle(message: "...")
    }
    
    @objc func refresh() {
        // 判断是不是下一首了
        if let track = Provider.shared.spotify?.currentTrack {
            self.lyricsManager.lyricLines = []
            updateBarTitle(message: "...")
            // 更新歌词
            LyricAPI(name: track.name, singer: track.artist, id: self.lyricsManager.currentTrackID, refresh: true)
                .lyrics(success: { item in
                    self.createMenuWithItems(items: item, i: 0)
                }) { message in
                    self.updateBarTitle(message: message)
                }
        }
    }
    
    func updateBarTitle(message: String) {
        DispatchQueue.main.async {
            self.statusBarItem?.button?.title = message
        }
    }
    
    @objc func search() {
        guard let statusItem = self.statusBarItem else { return }
        let popover = NSPopover()
        popover.behavior = .transient
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let contentView = SearchView(
                onSubmit: { name, singer in
                                // Handle the submitted text here
                                popover.performClose(nil)
                    LyricAPI.init(name: name, singer: singer, id: self.lyricsManager.currentTrackID, refresh: true)
                                    .lyrics { itemList in
                                        self.createMenuWithItems(items: itemList, i: 0)
                                    } failure: { message in
                                        self.updateBarTitle(message: message)
                                    }
                            },
                 name: self.lyricsManager.song,
                 singer: self.lyricsManager.singer
            )
            popover.contentViewController = NSHostingController(rootView: contentView)
            popover.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: .minY)
        }
    }
    
    @objc func detail() {
        guard let statusItem = self.statusBarItem else { return }
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 700)
        popover.behavior = .transient
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let contentView = DetailView(lyricsManager: lyricsManager)
            popover.contentViewController = NSHostingController(rootView: contentView)
            popover.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: .minY)
        }
    }
    
    @objc func hud() {
        DispatchQueue.main.async {
            self.hudWindow = LyricsHUD(lyricsManager: self.lyricsManager)
            self.hudWindow?.showWindow()
        }
    }
}
