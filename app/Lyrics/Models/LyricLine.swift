import Foundation

struct LyricWord: Identifiable, Equatable {
    var id = UUID()
    let text: String
    let beg: TimeInterval
    let end: TimeInterval
}

struct LyricLine: Identifiable {
    var id = UUID()
    let beg: TimeInterval
    let text: String
    let tran: String
    let end: TimeInterval
    var words: [LyricWord] = []
}
