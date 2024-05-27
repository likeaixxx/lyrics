//
//  Lyrics.swift
//  lyrics-v3
//
//  Created by 陈爱全 on 2024/5/15.
//

import Foundation
import Combine

let QQ    = "QQ Music"
let KuGou = "KuGou Music"
let NetEase = "NetEase Music"

struct LyricLine: Identifiable {
    var id = UUID()
    let beg: TimeInterval
    let text: String
    let end: TimeInterval
}

struct LyricResponseBody: Codable {
    let code: Int
    let message: String?
    let data: [LyricResponseItem]?
}

struct LyricResponseItem: Codable {
    let singer: String
    let name: String
    let sid: String
    let lid: String
    let lyrics: String
    let type: String
}

extension LyricResponseItem {

    func parseLyrics() -> [LyricLine] {
        guard let lyricsData = Data(base64Encoded: self.lyrics),
              let lyrics = String(data: lyricsData, encoding: .utf8) else {
            print("Failed to decode lyrics from data.")
            return []
        }
        
        let lines = lyrics.split(separator: "\n").compactMap { lyricsLine -> LyricLine? in
            let components = lyricsLine.components(separatedBy: "]")
            guard components.count > 1,
                  let timeString = components.first?.trimmingCharacters(in: CharacterSet(charactersIn: "[]")),
                  let text = components.last,
                  let minutes = Int(timeString.components(separatedBy: ":").first ?? ""),
                  let seconds = Int(timeString.components(separatedBy: ":").last?.components(separatedBy: ".").first ?? ""),
                  let milliseconds = Int(timeString.components(separatedBy: ":").last?.components(separatedBy: ".").last ?? "") else { return nil }
            
            let totalSeconds = TimeInterval(minutes * 60 + seconds) + TimeInterval(milliseconds) / 1000.0
            let line = text.decodeHTML()
            return line.isEmpty ? nil : LyricLine(beg: totalSeconds, text: line, end: TimeInterval(0))
        }

        return lines.enumerated().map { index, line in
            LyricLine(beg: line.beg, text: line.text, end: (index + 1 < lines.count) ? lines[index + 1].beg : line.beg + 5.0)
        }
    }
}

extension String {
    // 歌词提出html文本
    func decodeHTML() -> String {
        return self
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
