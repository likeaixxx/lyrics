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
            Text("Research")
            TextField("Song Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            TextField("Singer", text: $singer)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: {
                onSubmit(name, singer)
            }) {
                Text("Submit")
                    .foregroundColor(.blue)
            }
        }
        .frame(width: 150, height: 100)
        .padding()
    }
}

struct DetailView: View {
    @ObservedObject var lyricsManager: LyricsManager

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    Spacer() // Push content downwards
                    ForEach(lyricsManager.lyricLines) { line in
                        Text(line.text)
                            .font(.headline)
                            .fontWeight(line.beg <= lyricsManager.position && lyricsManager.position <= line.end ? .bold : .regular)
                            .foregroundColor(line.beg <= lyricsManager.position && lyricsManager.position <= line.end ? .green : line.beg < lyricsManager.position ? .gray : .teal)
                            .frame(maxWidth: .infinity, alignment: .center) // 水平居中
                            .id(line.id) // 为每一行设置唯一的 id
                    }
                    Spacer() // Push content upwards
                }
                .background(Color.clear) // 父视图背景也是透明的
            }
            .frame(maxWidth: .infinity, alignment: .center) // 水平居中
            .background(Color.clear) // 父视图背景也是透明的
            .onChange(of: lyricsManager.position) { newPosition in
                // 滚动到当前歌词行
                if let currentLine = lyricsManager.lyricLines.first(where: { $0.beg <= newPosition && newPosition <= $0.end }) {
                    withAnimation {
                        proxy.scrollTo(currentLine.id, anchor: .center)
                    }
                }
            }
        }
    }
}
