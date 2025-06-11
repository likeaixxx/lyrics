//
//  LyricsView.swift
//  lyrics-v3
//
//  Created by 陈爱全 on 2024/5/16.
//
import SwiftUI

struct SearchView: View {
    var onSubmit: (String, String) -> Void
    @State var name: String
    @State var singer: String
    
    var body: some View {
        VStack {
            TextField("Song Name", text: $name)
            TextField("Singer", text: $singer)
            Button(action: {
                onSubmit(name, singer)
            }) {
                Text("Submit")
            }
        }
        .frame(width: 125, height: 70)
        .padding()
    }
}

struct DetailView: View {
    @ObservedObject var lyricsManager: LyricsManager
    @State private var scale: CGFloat = 1.0 // 缩放比例

    // 你可以自定义基础字号
    let baseFontSize: CGFloat = 13

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    Spacer()
                    ForEach(lyricsManager.lyricLines) { line in
                        Text(line.text)
                            .font(.system(size: line.beg <= lyricsManager.position && lyricsManager.position <= line.end ? baseFontSize * scale  * 1.2 : baseFontSize * scale))
                            // .font(.system(size: baseFontSize * scale))
                            .fontWeight(line.beg <= lyricsManager.position && lyricsManager.position <= line.end ? .bold : .regular)
                            .foregroundColor(line.beg <= lyricsManager.position && lyricsManager.position <= line.end ? .teal : .gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center) 
                            .id(line.id)

                        if !line.tran.isEmpty {
                            Text(line.tran)
                                .font(.system(size: line.beg <= lyricsManager.position && lyricsManager.position <= line.end ? baseFontSize * scale : baseFontSize * scale * 0.9))
                                .fontWeight(line.beg <= lyricsManager.position && lyricsManager.position <= line.end ? .bold : .regular)
                                .foregroundColor(line.beg <= lyricsManager.position && lyricsManager.position <= line.end ? .teal : .gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 5)
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
                        // 限制缩放范围
                        scale = min(max(0.5, value), 3.0)
                    }
            )
        }
    }
}

struct OffsetView: View {
    @ObservedObject var lyricsManager: LyricsManager
    var onSubmit: (Int64) -> Void

    var body: some View {
        VStack {
            TextField("", value: $lyricsManager.offset, formatter: NumberFormatter())
                .frame(width: 80)
            HStack {
                Button(action: increaseOffset) {
                    Text("+")
                }
                Button(action: decreaseOffset) {
                    Text("-")
                }
                Button(action: {
                    onSubmit(lyricsManager.offset)
                }) {
                    Text("Submit")
                }
            }
        }
        .padding()
    }

    func decreaseOffset() {
        lyricsManager.offset -= 100
    }

    func increaseOffset() {
        lyricsManager.offset += 100
    }
}
