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
    static let baseFontSize: CGFloat = 13
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
private extension LyricsManager {
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
    @ObservedObject var lyricsManager: LyricsManager
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: UIConstants.lyricSpacing) {
                    Spacer()
                    ForEach(lyricsManager.lyricLines) { line in
                        LyricLineView(
                            line: line,
                            isActive: lyricsManager.isLineActive(line),
                            scale: scale
                        )
                        .id(line.id)
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
    let line: LyricLine
    let isActive: Bool
    let scale: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            Text(line.text)
                .font(.system(size: UIConstants.baseFontSize * scale * (isActive ? UIConstants.activeFontScale : 1.0)))
                .fontWeight(isActive ? .bold : .regular)
                .foregroundColor(isActive ? UIConstants.activeColor : UIConstants.inactiveColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            
            if !line.tran.isEmpty {
                Text(line.tran)
                    .font(.system(size: UIConstants.baseFontSize * scale * UIConstants.translatFontScale))
                    .fontWeight(isActive ? .bold : .regular)
                    .foregroundColor(isActive ? UIConstants.activeColor : UIConstants.inactiveColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, UIConstants.translationPadding)
            }
        }
    }
}

// MARK: - OffsetView
struct OffsetView: View {
    @ObservedObject var lyricsManager: LyricsManager
    var onSubmit: (Int64) -> Void
    
    var body: some View {
        VStack {
            TextField("", value: $lyricsManager.offset, formatter: NumberFormatter())
                .frame(width: UIConstants.offsetTextFieldWidth)
            HStack {
                Button(action: { lyricsManager.offset -= UIConstants.offsetStep }) {
                    Text("+")
                }
                Button(action: { lyricsManager.offset += UIConstants.offsetStep }) {
                    Text("-")
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
struct SetHostView: View {
    @State var host: String
    var onSubmit: (String) -> Void
    
    var body: some View {
        VStack {
            TextField("API Host", text: $host)
            HStack {
                Button(action: { onSubmit(host) }) {
                    Text("Submit")
                }
            }
        }
        .padding()
    }
}
