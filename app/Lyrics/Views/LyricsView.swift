//
//  LyricsView.swift
//  lyrics-v3
//
//  Created by likeai on 2024/5/16.
//
import SwiftUI

// MARK: - Constants
private struct UIConstants {
    static let baseFontSize: CGFloat = 14
    static let activeFontScale: CGFloat = 1.2
    static let translatFontScale: CGFloat = 0.9
    static let minScale: CGFloat = 0.5
    static let maxScale: CGFloat = 3.0
    static let offsetStep: Int64 = 100
    static let searchViewWidth: CGFloat = 125
    static let searchViewHeight: CGFloat = 70
    static let offsetTextFieldWidth: CGFloat = 80
    static let lyricSpacing: CGFloat = 10
    static let translationPadding: CGFloat = 5
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
            Button(action: { onSubmit(name, singer) }) { Text("Submit") }
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
                        VStack(spacing: 12) {
                            Image(systemName: "music.note")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("暂无歌词")
                                .font(.title3)
                                .foregroundColor(.primary.opacity(0.6))
                            if !lyricsManager.song.isEmpty {
                                Text(lyricsManager.song)
                                    .font(.body).foregroundColor(.gray)
                                if !lyricsManager.singer.isEmpty {
                                    Text(lyricsManager.singer)
                                        .font(.caption).foregroundColor(.gray.opacity(0.8))
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
                                positionAnchor: lyricsManager.positionAnchor
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
                if let line = lyricsManager.lyricLines.first(where: {
                    $0.beg <= newPosition && newPosition <= $0.end
                }) {
                    withAnimation { proxy.scrollTo(line.id, anchor: .center) }
                }
            }
            .gesture(
                MagnificationGesture().onChanged { value in
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
    let positionAnchor: LyricsViewModel.PositionAnchor

    @AppStorage("lyricFontName") private var fontName: String = "Google Sans Code"

    var body: some View {
        VStack(spacing: 0) {
            let fontSize = UIConstants.baseFontSize * scale
                * (isActive ? UIConstants.activeFontScale : 1.0)

            if !lyricLine.words.isEmpty {
                // TimelineView 保持视图标识不变（不随 isActive 切换视图类型）。
                // 每帧直接从 positionAnchor 推算 progress，激活第一帧即是正确进度，
                // 彻底消除"先清底色再着色"的闪烁。
                // inactive 行每帧只执行一次 guard-return，CPU 开销微乎其微。
                TimelineView(.animation(paused: !isActive)) { context in
                    GradientSweepText(
                        text: lyricLine.text,
                        progress: timeProgress(at: context.date),
                        isActive: isActive,
                        fontName: fontName,
                        fontSize: fontSize
                    )
                }
            } else {
                Text(lyricLine.text)
                    .font(.custom(fontName, size: fontSize))
                    .fontWeight(isActive ? .bold : .regular)
                    .foregroundColor(isActive ? UIConstants.activeColor : UIConstants.inactiveColor)
                    .shadow(color: isActive ? UIConstants.activeColor.opacity(0.6) : .clear,
                            radius: 10, x: 0, y: 0)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }

            if !lyricLine.tran.isEmpty {
                Text(lyricLine.tran)
                    .font(.custom(fontName,
                                  size: UIConstants.baseFontSize * scale * UIConstants.translatFontScale))
                    .fontWeight(isActive ? .bold : .regular)
                    .foregroundColor(isActive ? UIConstants.activeColor : UIConstants.inactiveColor)
                    .shadow(color: isActive ? UIConstants.activeColor.opacity(0.4) : .clear,
                            radius: 5, x: 0, y: 0)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, UIConstants.translationPadding)
            }
        }
        // TimelineView 直接推算进度，无需 onChange 驱动动画。
    }

    /// 从 positionAnchor 外推当前播放位置，映射为行内 0…1 进度。
    /// inactive 行直接返回 0（一次 guard 判断，零额外计算）。
    private func timeProgress(at date: Date) -> Double {
        guard isActive,
              let lineStart = lyricLine.words.first?.beg,
              let lineEnd   = lyricLine.words.last?.end,
              lineEnd > lineStart else { return 0 }
        let elapsed  = date.timeIntervalSince(positionAnchor.date)
        let position = positionAnchor.position + elapsed
        return min(1, max(0, (position - lineStart) / (lineEnd - lineStart)))
    }
}


// MARK: - GradientSweepText
/// Renders `text` with a left-to-right teal→gray gradient controlled by `progress`.
///
/// Design notes:
/// - No `.frame(maxWidth: .infinity)` — gradient coordinate space = text's own bounds,
///   so the sweep is always proportional to visible text width regardless of window size.
/// - `feather` is intentionally narrow (0.06) to produce a crisp, LyricsX-style edge
///   rather than a wide blur that looks smeared.
private struct GradientSweepText: View {
    let text: String
    let progress: Double   // 0…1, driven by Core Animation via withAnimation(.linear)
    let isActive: Bool
    let fontName: String
    let fontSize: CGFloat

    /// Half-width of the soft transition edge, as a fraction of text width.
    private let feather: Double = 0.06

    var body: some View {
        let color1 = isActive ? UIConstants.activeColor : UIConstants.inactiveColor
        let color2 = isActive ? UIConstants.activeColor : UIConstants.inactiveColor
        let color3 = UIConstants.inactiveColor
        let color4 = UIConstants.inactiveColor

        Text(text)
            .font(.custom(fontName, size: fontSize))
            // inactive 时 regular，active 时 bold —— 同一个 Text 改属性，不换视图
            .fontWeight(isActive ? .bold : .regular)
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        // progress=0 时全文为灰；progress=1 时全文为 teal
                        // teal 区域 [0, progress-feather]，过渡区 [progress-feather, progress+feather]
                        .init(color: color1, location: max(0, progress - feather * 2)),
                        .init(color: color2, location: max(0, progress - feather)),
                        .init(color: color3, location: min(1, progress + feather)),
                        .init(color: color4, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            // inactive 时无光晕，active 时有光晕
            .shadow(color: isActive ? UIConstants.activeColor.opacity(0.5) : .clear,
                    radius: 8, x: 0, y: 0)
            .multilineTextAlignment(.center)
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
                Button(action: { lyricsManager.offset -= UIConstants.offsetStep }) { Text("-") }
                Button(action: { lyricsManager.offset += UIConstants.offsetStep }) { Text("+") }
                Button(action: { onSubmit(lyricsManager.offset) }) { Text("Submit") }
            }
        }
        .padding()
    }
}

// MARK: - SetHostView
