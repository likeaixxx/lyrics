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
    let tran: String
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
    let trans: String
    let type: String
    let offset: Int64
}

extension LyricResponseItem {
    func Lyrics() -> [LyricLine] {
        guard let lyricsData = Data(base64Encoded: self.lyrics),
              let lyrics = String(data: lyricsData, encoding: .utf8) else {
            print("Failed to decode lyrics from data. \(self.lyrics)")
            return []
        }
        
        let transData = Data(base64Encoded: self.trans)
        let trans = String(data: transData ?? Data(), encoding: .utf8)
        
        let lyricsLines = lyrics.components(separatedBy: "[")
        let transLines = trans?.components(separatedBy: "[") ?? []
        
        var result = [LyricLine]()
        
        for (index, lyricsLine) in lyricsLines.enumerated() {
            let lyricsComponents = lyricsLine.components(separatedBy: "]")
            let transComponents = index < transLines.count ? transLines[index].components(separatedBy: "]") : []
            
            guard lyricsComponents.count > 1,
                  let timeString = lyricsComponents.first?.trimmingCharacters(in: CharacterSet(charactersIn: "[]")),
                  let text = lyricsComponents.last,
                  let minutes = Int(timeString.components(separatedBy: ":").first ?? ""),
                  let seconds = Int(timeString.components(separatedBy: ":").last?.components(separatedBy: ".").first ?? ""),
                  let milliseconds = Int(timeString.components(separatedBy: ":").last?.components(separatedBy: ".").last ?? "") else { continue }
            
            let totalSeconds = TimeInterval(minutes * 60 + seconds) + TimeInterval(milliseconds) / 1000.0
            let line = text.decodeHTML()
            let tran = index < transLines.count ? (transComponents.last?.decodeHTML() ?? "") : ""
            
            if !line.isEmpty {
                let nextTimeString = index + 1 < lyricsLines.count ? lyricsLines[index + 1].components(separatedBy: "]").first : nil
                let nextMinutes = Int(nextTimeString?.components(separatedBy: ":").first ?? "") ?? minutes
                let nextSeconds = Int(nextTimeString?.components(separatedBy: ":").last?.components(separatedBy: ".").first ?? "") ?? seconds
                let nextMilliseconds = Int(nextTimeString?.components(separatedBy: ":").last?.components(separatedBy: ".").last ?? "") ?? milliseconds
                let nextTotalSeconds = TimeInterval(nextMinutes * 60 + nextSeconds) + TimeInterval(nextMilliseconds) / 1000.0
                let end = (index + 1 < lyricsLines.count) ? nextTotalSeconds : totalSeconds + 5.0
                result.append(LyricLine(beg: totalSeconds, text: line, tran: tran, end: end))
            }
        }
        return result
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
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: "")
            .replacingOccurrences(of: "//", with: "")
            .replacingOccurrences(of: "\\", with: "")
    }
}
