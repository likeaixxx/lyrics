//
//  Lyrics.swift
//  lyrics-v3
//
//  Created by likeai on 2024/5/15.
//

import Foundation
import Combine

// MARK: - Music Source Constants
enum MusicSource {
    static let qq = "QQ Music"
    static let kuGou = "KuGou Music"
    static let netEase = "NetEase Music"
}

// MARK: - Models
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

// MARK: - Timestamp Model
private struct Timestamp {
    let minutes: Int
    let seconds: Int
    let milliseconds: Int
    
    var timeInterval: TimeInterval {
        TimeInterval(minutes * 60 + seconds) + TimeInterval(milliseconds) / 1000.0
    }
}

// MARK: - LyricResponseItem Extension
extension LyricResponseItem {
    func Lyrics() -> [LyricLine] {
        let lyricsLines = decodeBase64Lines(self.lyrics)
        let transLines = decodeBase64Lines(self.trans)
        
        guard !lyricsLines.isEmpty else { return [] }
        
        var result = [LyricLine]()
        
        for (index, lyricsLine) in lyricsLines.enumerated() {
            guard let lyricData = parseLyricLine(lyricsLine),
                  !lyricData.text.isEmpty else { continue }
            
            let transText = index < transLines.count ? parseTranslationLine(transLines[index]) : ""
            let nextTime = index + 1 < lyricsLines.count ?
                extractTimestamp(from: lyricsLines[index + 1]) :
                nil
            
            let endTime = nextTime?.timeInterval ?? (lyricData.time.timeInterval + 5.0)
            result.append(LyricLine(
                beg: lyricData.time.timeInterval,
                text: lyricData.text,
                tran: transText,
                end: endTime
            ))
        }
        
        return result
    }
    
    // MARK: - Private Helpers
    
    private func decodeBase64Lines(_ base64String: String) -> [String] {
        guard let data = Data(base64Encoded: base64String),
              let decodedString = String(data: data, encoding: .utf8) else {
            if !base64String.isEmpty {
                print("Failed to decode base64 string: \(base64String)")
            }
            return []
        }
        return decodedString.components(separatedBy: "[")
    }
    
    private func parseLyricLine(_ line: String) -> (time: Timestamp, text: String)? {
        let components = line.components(separatedBy: "]")
        guard components.count > 1,
              let timestamp = extractTimestamp(from: line) else { return nil }
        
        let text = components.last?.decodeHTML() ?? ""
        return (time: timestamp, text: text)
    }
    
    private func parseTranslationLine(_ line: String) -> String {
        let components = line.components(separatedBy: "]")
        return components.last?.decodeHTML() ?? ""
    }
    
    private func extractTimestamp(from line: String) -> Timestamp? {
        let components = line.components(separatedBy: "]")
        guard let timeString = components.first?.trimmingCharacters(in: CharacterSet(charactersIn: "[]")) else {
            return nil
        }
        return Timestamp.parse(timeString)
    }
}

// MARK: - Timestamp Parsing
extension Timestamp {
    static func parse(_ timeString: String) -> Timestamp? {
        let parts = timeString.components(separatedBy: ":")
        guard parts.count >= 2,
              let minutes = Int(parts[0]) else { return nil }
        
        let subparts = parts[1].components(separatedBy: ".")
        guard subparts.count >= 2,
              let seconds = Int(subparts[0]),
              let milliseconds = Int(subparts[1]) else { return nil }
        
        return Timestamp(minutes: minutes, seconds: seconds, milliseconds: milliseconds)
    }
}

// MARK: - String HTML Decoding
extension String {
    /// Decode HTML entities and remove whitespace characters
    func decodeHTML() -> String {
        let htmlEntityMap: [String: String] = [
            "&apos;": "'",
            "&quot;": "\"",
            "&lt;": "<",
            "&gt;": ">",
            "&amp;": "&"
        ]
        
        let whitespaceCharacters = ["\n", "\r", "\t", "//", "\\"]
        
        var result = self
        
        // Replace HTML entities
        htmlEntityMap.forEach { entity, replacement in
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // Remove whitespace characters
        whitespaceCharacters.forEach { char in
            result = result.replacingOccurrences(of: char, with: "")
        }
        
        return result
    }
}
