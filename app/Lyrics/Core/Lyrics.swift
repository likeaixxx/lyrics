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

struct LyricLine {
    let time: TimeInterval
    let text: String
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
    func parseLyrics() -> [LyricLine]? {
        guard let lyricsData = Data(base64Encoded: self.lyrics),
              let lyrics = String(data: lyricsData, encoding: .utf8)
        else {
            print("Failed to decode lyrics from data.")
            return nil
        }
        
        return lyrics.split(separator: "\n")
            .map(String.init)
            .compactMap{ lyricsLine in
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
