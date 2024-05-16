//
//  LyricsView.swift
//  lyrics-v3
//
//  Created by 陈爱全 on 2024/5/16.
//

import SwiftUI

struct SearchView: View {
    var onSubmit: (String, String) -> Void
    @State private var name: String = ""
    @State private var singer: String = ""
    
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
        List(lyricsManager.lyricLines, id: \.time) { line in
            if line.time < lyricsManager.position {
                Text(line.text)
                    .foregroundColor(.gray)
            } else {
                Text(line.text)
                    .foregroundColor(.green)
            }
        }
    }
}
