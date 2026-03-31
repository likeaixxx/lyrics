import Foundation

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
    func rawLyrics() -> String {
        guard let data = Data(base64Encoded: self.lyrics),
              let decodedString = String(data: data, encoding: .utf8) else {
            return ""
        }
        return decodedString
    }

    func Lyrics() -> [LyricLine] {
        guard let data = Data(base64Encoded: self.lyrics),
              let decodedString = String(data: data, encoding: .utf8) else {
            return []
        }
        
        var transMap = [Int: String]()
        if let transData = Data(base64Encoded: self.trans),
           let transString = String(data: transData, encoding: .utf8) {
            let tLines = transString.components(separatedBy: .newlines)
            for tLine in tLines {
                // Typical LRC format: [mm:ss.xx] translated text
                if let tLineMatch = parseLrcLine(tLine) {
                    let key = Int(tLineMatch.time * 10) // Approx matching via 100ms
                    transMap[key] = tLineMatch.text
                }
            }
        }

        var result = [LyricLine]()
        let lines = decodedString.components(separatedBy: .newlines)
        
        for index in 0..<lines.count {
            let line = lines[index]
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            
            if let lyricData = parseEnhancedLyricLine(line) {
                if lyricData.text.trimmingCharacters(in: .whitespaces).isEmpty && lyricData.words.isEmpty { continue }
                
                // Attempt to find translation by approx time matching
                let key = Int(lyricData.time * 10)
                let transText = transMap[key] ?? ""
                
                result.append(LyricLine(
                    beg: lyricData.time,
                    text: lyricData.text,
                    tran: transText,
                    end: lyricData.endTime,
                    words: lyricData.words
                ))
            } else if let lyricData = parseLrcLine(line) {
                if lyricData.text.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                
                let key = Int(lyricData.time * 10)
                let transText = transMap[key] ?? ""
                
                result.append(LyricLine(
                    beg: lyricData.time,
                    text: lyricData.text,
                    tran: transText,
                    end: lyricData.time + 5.0, // Default duration if not specified
                    words: []
                ))
            }
        }
        
        // Fix up default LRC end times
        for i in 0..<result.count {
            if result[i].words.isEmpty && i + 1 < result.count {
                result[i] = LyricLine(
                    id: result[i].id,
                    beg: result[i].beg,
                    text: result[i].text,
                    tran: result[i].tran,
                    end: result[i+1].beg,
                    words: []
                )
            }
        }

        return result
    }

    // MARK: - Private Helpers
    
    // Parse QRC, KRC, YRC Lines: format [start_ms,duration_ms] <tags>
    private func parseEnhancedLyricLine(_ line: String) -> (time: TimeInterval, endTime: TimeInterval, text: String, words: [LyricWord])? {
        let enhancedRegex = try? NSRegularExpression(pattern: #"^\[(\d+),(\d+)\](.*)"#)
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        
        guard let match = enhancedRegex?.firstMatch(in: line, range: nsRange),
              match.numberOfRanges >= 4,
              let startRange = Range(match.range(at: 1), in: line),
              let durRange = Range(match.range(at: 2), in: line),
              let contentRange = Range(match.range(at: 3), in: line),
              let startMs = Int(line[startRange]),
              let durMs = Int(line[durRange]) else {
            return nil
        }
        
        let startTime = TimeInterval(startMs) / 1000.0
        let duration = TimeInterval(durMs) / 1000.0
        let endTime = startTime + duration
        let content = String(line[contentRange])
        
        var words = [LyricWord]()
        var plainText = ""
        
        // 1. kugouInlineTagRegex = <(\d+),(\d+),\d+>([^<]*)
        let kugouRegex = try? NSRegularExpression(pattern: #"<(\d+),(\d+),\d+>([^<]*)"#)
        if let kMatches = kugouRegex?.matches(in: content, range: NSRange(location: 0, length: content.utf16.count)), !kMatches.isEmpty {
            for m in kMatches {
                if let r1 = Range(m.range(at: 1), in: content), let r2 = Range(m.range(at: 2), in: content), let r3 = Range(m.range(at: 3), in: content) {
                    let offsetMs = Int(content[r1]) ?? 0
                    let durMs = Int(content[r2]) ?? 0
                    let text = String(content[r3]).decodeHTML()
                    let wb = startTime + (TimeInterval(offsetMs) / 1000.0)
                    let we = wb + (TimeInterval(durMs) / 1000.0)
                    words.append(LyricWord(text: text, beg: wb, end: we))
                    plainText += text
                }
            }
            return (startTime, endTime, plainText, words)
        }
        
        // 2. netEaseYrcInlineTagRegex = \((\d+),(\d+),\d+\)([^(]*)
        let yrcRegex = try? NSRegularExpression(pattern: #"\((?:\d+,)?(\d+),(\d+),\d+\)([^(]*)"#)
        let yrcFallbackRegex = try? NSRegularExpression(pattern: #"\((\d+),(\d+),\d+\)([^(]*)"#)
        
        let yMatches = yrcFallbackRegex?.matches(in: content, range: NSRange(location: 0, length: content.utf16.count))
        if let yMatches = yMatches, !yMatches.isEmpty {
            for m in yMatches {
                if let r1 = Range(m.range(at: 1), in: content), let r2 = Range(m.range(at: 2), in: content), let r3 = Range(m.range(at: 3), in: content) {
                    let offsetMs = Int(content[r1]) ?? 0
                    let durMs = Int(content[r2]) ?? 0
                    let text = String(content[r3]).decodeHTML()
                    let wb = TimeInterval(offsetMs) / 1000.0
                    let we = wb + (TimeInterval(durMs) / 1000.0)
                    words.append(LyricWord(text: text, beg: wb, end: we))
                    plainText += text
                }
            }
            return (startTime, endTime, plainText, words)
        }
        
        // 3. qqmusicInlineTagRegex = ([^(]*)\((\d+),(\d+)\)
        let qqRegex = try? NSRegularExpression(pattern: #"([^(]*)\((\d+),(\d+)\)"#)
        if let qMatches = qqRegex?.matches(in: content, range: NSRange(location: 0, length: content.utf16.count)), !qMatches.isEmpty {
            for m in qMatches {
                if let r1 = Range(m.range(at: 1), in: content), let r2 = Range(m.range(at: 2), in: content), let r3 = Range(m.range(at: 3), in: content) {
                    let text = String(content[r1]).decodeHTML()
                    let startMs = Int(content[r2]) ?? 0
                    let durMs = Int(content[r3]) ?? 0
                    let wb = TimeInterval(startMs) / 1000.0
                    let we = wb + (TimeInterval(durMs) / 1000.0)
                    words.append(LyricWord(text: text, beg: wb, end: we))
                    plainText += text
                }
            }
            return (startTime, endTime, plainText, words)
        }

        // 4. netEaseKLyricTagRegex = \(0,(\d+)\)([^(]+)(?:\(0,1\) )?
        let kLyricRegex = try? NSRegularExpression(pattern: #"\(0,(\d+)\)([^(]+)"#)
        if let kLyricMatches = kLyricRegex?.matches(in: content, range: NSRange(location: 0, length: content.utf16.count)), !kLyricMatches.isEmpty {
            var currentStart = startTime
            for m in kLyricMatches {
                if let r1 = Range(m.range(at: 1), in: content), let r2 = Range(m.range(at: 2), in: content) {
                    let durMs = Int(content[r1]) ?? 0
                    // Fix NetEase whitespace trailing issue on internal tags if any
                    let text = String(content[r2]).decodeHTML()
                    let we = currentStart + (TimeInterval(durMs) / 1000.0)
                    words.append(LyricWord(text: text, beg: currentStart, end: we))
                    plainText += text
                    currentStart = we
                }
            }
            return (startTime, endTime, plainText, words)
        }

        return (startTime, endTime, content.decodeHTML(), [])
    }

    // Parse Standard LRC Lines: format [mm:ss.xx]Text
    private func parseLrcLine(_ line: String) -> (time: TimeInterval, text: String)? {
        let regex = try? NSRegularExpression(pattern: #"\[(\d+):(\d+(?:\.\d+)?)\](.*)"#)
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        
        guard let match = regex?.firstMatch(in: line, range: nsRange),
              match.numberOfRanges >= 4,
              let minRange = Range(match.range(at: 1), in: line),
              let secRange = Range(match.range(at: 2), in: line),
              let contentRange = Range(match.range(at: 3), in: line),
              let minutes = Double(line[minRange]),
              let seconds = Double(line[secRange]) else {
            return nil
        }
        
        let time = minutes * 60.0 + seconds
        let content = String(line[contentRange]).decodeHTML()
        return (time, content)
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
