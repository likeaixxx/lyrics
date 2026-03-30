//
//  LyricsView.swift
//  lyrics-v3
//
//  Created by likeai on 2024/5/16.
//
import SwiftUI

// MARK: - Constants
private struct UIConstants {
    // Font sizes
    static let baseFontSize: CGFloat = 14
    static let activeFontScale: CGFloat = 1.2
    static let translatFontScale: CGFloat = 0.9

    // Scale range
    static let minScale: CGFloat = 0.5
    static let maxScale: CGFloat = 3.0

    // Offsets
    static let offsetStep: Int64 = 100

    // Layout
    static let searchViewWidth: CGFloat = 125
    static let searchViewHeight: CGFloat = 70
    static let offsetTextFieldWidth: CGFloat = 80
    static let lyricSpacing: CGFloat = 10
    static let translationPadding: CGFloat = 5

    // Colors
    static let activeColor = Color.teal
    static let inactiveColor = Color.gray
}

// MARK: - Helper Extensions
private extension LyricsViewModel {
    func isLineActive(_ line: LyricLine) -> Bool {
        line.beg <= position && position <= line.end
    }
}

private extension CGFloat {
    func clamped(min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, min), max)
    }
}

// MARK: - SearchView
struct SearchView: View {
    var onSubmit: (String, String) -> Void
    @State var name: String
    @State var singer: String

    var body: some View {
        VStack {
            TextField("Song Name", text: $name)
            TextField("Singer", text: $singer)
            Button(action: { onSubmit(name, singer) }) {
                Text("Submit")
            }
        }
        .frame(width: UIConstants.searchViewWidth, height: UIConstants.searchViewHeight)
        .padding()
    }
}

// MARK: - DetailView
struct DetailView: View {
    @ObservedObject var lyricsManager: LyricsViewModel
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: UIConstants.lyricSpacing) {
                    Spacer()
                    if lyricsManager.lyricLines.isEmpty {
                        // 空状态提示
                        VStack(spacing: 12) {
                            Image(systemName: "music.note")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("暂无歌词")
                                .font(.title3)
                                .foregroundColor(.primary.opacity(0.6))
                            if !lyricsManager.song.isEmpty {
                                Text(lyricsManager.song)
                                    .font(.body)
                                    .foregroundColor(.gray)
                                if !lyricsManager.singer.isEmpty {
                                    Text(lyricsManager.singer)
                                        .font(.caption)
                                        .foregroundColor(.gray.opacity(0.8))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(lyricsManager.lyricLines) { line in
                            LyricLineView(
                                lyricLine: line,
                                isActive: lyricsManager.isLineActive(line),
                                scale: scale,
                                position: lyricsManager.position
                            )
                            .id(line.id)
                        }
                    }
                    Spacer()
                }
                .background(Color.clear)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color.clear)
            .onChange(of: lyricsManager.position) { newPosition in
                if let currentLine = lyricsManager.lyricLines.first(where: { $0.beg <= newPosition && newPosition <= $0.end }) {
                    withAnimation {
                        proxy.scrollTo(currentLine.id, anchor: .center)
                    }
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = value.clamped(min: UIConstants.minScale, max: UIConstants.maxScale)
                    }
            )
        }
    }
}

// MARK: - LyricLineView
private struct LyricLineView: View {
    let lyricLine: LyricLine
    let isActive: Bool
    let scale: CGFloat
    let position: Double

    // Read font preference
    @AppStorage("lyricFontName") private var fontName: String = "Google Sans Code"

    var body: some View {
        VStack(spacing: 0) {
            let fontSize = UIConstants.baseFontSize * scale * (isActive ? UIConstants.activeFontScale : 1.0)
            
            if isActive && !lyricLine.words.isEmpty {
                Text(attributedText(for: lyricLine, position: position))
                    .font(.custom(fontName, size: fontSize))
                    .fontWeight(.bold)
                    // Apply a general glow to the entire active line
                    .shadow(color: UIConstants.activeColor.opacity(0.6), radius: 10, x: 0, y: 0) 
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            } else {
                Text(lyricLine.text)
                    .font(.custom(fontName, size: fontSize))
                    .fontWeight(isActive ? .bold : .regular)
                    .foregroundColor(isActive ? UIConstants.activeColor : Color.primary.opacity(0.6)) // Inactive use primary with opacity
                    .shadow(color: isActive ? UIConstants.activeColor.opacity(0.6) : .clear, radius: 10, x: 0, y: 0) // Glow effect
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }

            if (!lyricLine.tran.isEmpty) {
                Text(lyricLine.tran)
                    .font(.custom(fontName, size: UIConstants.baseFontSize * scale * UIConstants.translatFontScale))
                    .fontWeight(isActive ? .bold : .regular)
                    .foregroundColor(isActive ? UIConstants.activeColor : Color.primary.opacity(0.6))
                    .shadow(color: isActive ? UIConstants.activeColor.opacity(0.4) : .clear, radius: 5, x: 0, y: 0)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, UIConstants.translationPadding)
            }
        }
    }
    
    // Attributed String calculation for word-by-word progress
    private func attributedText(for line: LyricLine, position: Double) -> AttributedString {
        var attrStr = AttributedString("")
        for word in line.words {
            var wordAttr = AttributedString(word.text)
            // If the playback position has passed the word's start time
            // To make it feel responsive, color it active when it starts.
            if position >= word.beg {
                wordAttr.foregroundColor = UIConstants.activeColor
            } else {
                wordAttr.foregroundColor = Color.primary.opacity(0.6)
            }
            attrStr.append(wordAttr)
        }
        return attrStr
    }
}

// MARK: - OffsetView
struct OffsetView: View {
    @ObservedObject var lyricsManager: LyricsViewModel
    var onSubmit: (Int64) -> Void

    var body: some View {
        VStack {
            TextField("", value: $lyricsManager.offset, formatter: NumberFormatter())
                .frame(width: UIConstants.offsetTextFieldWidth)
            HStack {
                Button(action: { lyricsManager.offset -= UIConstants.offsetStep }) {
                    Text("-")
                }
                Button(action: { lyricsManager.offset += UIConstants.offsetStep }) {
                    Text("+")
                }
                Button(action: { onSubmit(lyricsManager.offset) }) {
                    Text("Submit")
                }
            }
        }
        .padding()
    }
}

// MARK: - SetHostView

