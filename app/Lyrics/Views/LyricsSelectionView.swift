//
//  LyricsSelectionView.swift
//  Lyrics
//
//  Created by likeai on 2026/01/21.
//

import SwiftUI
import Foundation

struct LyricsSelectionView: View {
    @ObservedObject var lyricsManager: LyricsViewModel
    @State private var items: [LyricResponseItem]
    let onSelect: (LyricResponseItem) -> Void
    let onSearch: (String, String, @escaping ([LyricResponseItem]) -> Void) -> Void

    @State private var selectedIndex: Int?
    @State private var searchTitle: String
    @State private var searchSinger: String
    @State private var isLoading: Bool = false
    @State private var previewLines: [LyricLine]
    @State private var activeLineId: UUID?
    @State private var isUserScrolling: Bool = false
    @State private var resumeFollowTask: DispatchWorkItem?

    // Initializer to allow pre-filling search fields from current VM state
    init(lyricsManager: LyricsViewModel,
         items: [LyricResponseItem],
         initialTitle: String,
         initialSinger: String,
         onSelect: @escaping (LyricResponseItem) -> Void,
         onSearch: @escaping (String, String, @escaping ([LyricResponseItem]) -> Void) -> Void) {
        self.lyricsManager = lyricsManager
        self._items = State(initialValue: items)
        self.onSelect = onSelect
        self.onSearch = onSearch
        _searchTitle = State(initialValue: initialTitle)
        _searchSinger = State(initialValue: initialSinger)
        _selectedIndex = State(initialValue: items.isEmpty ? nil : 0)
        _previewLines = State(initialValue: items.first?.Lyrics() ?? [])
        _activeLineId = State(initialValue: nil)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: List & Search
            VStack(spacing: 0) {
                // Search Header
                VStack(spacing: 16) {
                    Text("Search Lyrics")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundColor(.secondary)
                                .frame(width: 16)
                            TextField("Song Title", text: $searchTitle)
                                .textFieldStyle(.plain)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )

                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 16)
                            TextField("Singer", text: $searchSinger)
                                .textFieldStyle(.plain)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                    }
                    .onSubmit { doSearch() }

                    Button(action: doSearch) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text("Search")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(isLoading)
                }
                .padding(16)
                // Search header transparent so it adopts the sidebar background, or keep it distinct?
                // Let's keep it clean.

                Divider()
                    .background(Color.white.opacity(0.1))

                // Results List
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if items.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text(isLoading ? "Searching..." : "No results found")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                LyricRow(item: item, isSelected: selectedIndex == index)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedIndex = index
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
            }
            .frame(width: 260)
            .background(Color.black.opacity(0.3)) // Unified darker background for the sidebar

            Divider()
                .background(Color.black.opacity(0.5))

            // Right: Preview
            VStack(spacing: 0) {
                // Header
                ZStack {
                    // Left aligned label (Optional, maybe remove if it feels cluttered, but keeping it for context)
                    HStack {
                         Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary.opacity(0.5))
                        Spacer()
                    }

                    // Centered Song Info
                    if let item = selectedItem {
                        HStack(spacing: 8) {
                            Text(item.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("-")
                                .foregroundColor(.secondary)
                            Text(item.singer)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.secondary)

                            // Provider Badge
                            Text(item.type)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        .padding(.horizontal, 32) // Avoid overlapping with "Preview"
                        .lineLimit(1)
                    }
                }
                .frame(height: 60) // Taller header
                .padding(.horizontal, 16)
                .background(Color.black.opacity(0.2))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.white.opacity(0.05)),
                    alignment: .bottom
                )

                // Content
                ZStack {
                    if let item = selectedItem {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .center, spacing: 20) { // Center alignment for lyrics usually looks nice
                                    ForEach(previewLines) { line in
                                        let isActive = line.id == activeLineId
                                        VStack(spacing: 6) {
                                            Text(line.text)
                                                .font(.system(size: 16, weight: isActive ? .semibold : .medium, design: .rounded))
                                                .foregroundColor(isActive ? .teal : .primary)
                                                .multilineTextAlignment(.center)
                                                .fixedSize(horizontal: false, vertical: true)

                                            if !line.tran.isEmpty {
                                                Text(line.tran)
                                                    .font(.system(size: 14, weight: isActive ? .regular : .light, design: .rounded))
                                                    .foregroundColor(isActive ? .teal.opacity(0.8) : .secondary)
                                                    .multilineTextAlignment(.center)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .id(line.id)
                                    }
                                }
                                .padding(.vertical, 24)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 60) // Space for bottom bar
                            }
                            .onAppear {
                                updateActiveLine(position: lyricsManager.position)
                                scrollToActiveLine(proxy: proxy, force: true)
                            }
                            .onChange(of: lyricsManager.position) { newPosition in
                                guard lyricsManager.isPlaying else { return }
                                updateActiveLine(position: newPosition)
                            }
                            .onChange(of: lyricsManager.isPlaying) { isPlaying in
                                updateActiveLine(position: lyricsManager.position)
                                if isPlaying {
                                    scrollToActiveLine(proxy: proxy, force: true)
                                }
                            }
                            .onChange(of: selectedIndex) { _ in
                                previewLines = selectedItem?.Lyrics() ?? []
                                updateActiveLine(position: lyricsManager.position)
                                scrollToActiveLine(proxy: proxy, force: true)
                            }
                            .onChange(of: activeLineId) { newId in
                                guard newId != nil else { return }
                                scrollToActiveLine(proxy: proxy, force: false)
                            }
                            .onChange(of: isUserScrolling) { isScrolling in
                                if !isScrolling {
                                    scrollToActiveLine(proxy: proxy, force: true)
                                }
                            }
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { _ in
                                        pauseAutoFollow()
                                    }
                                    .onEnded { _ in
                                        scheduleAutoFollowResume()
                                    }
                            )
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "music.mic")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.3))
                                .padding(.bottom, 8)
                            Text("Select a track to preview lyrics")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Search and select a song from the sidebar")
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.3))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().background(Color.white.opacity(0.05))

                // Bottom Bar
                HStack(spacing: 12) {
                    Spacer()
                    Button("Cancel") {
                         NSApp.keyWindow?.close()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Use Lyric") {
                        if let item = selectedItem {
                            onSelect(item)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(selectedItem == nil)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(16)
                .background(Color.black.opacity(0.2)) // Matching header background
            }
        }
        .frame(width: 800, height: 550)
        .preferredColorScheme(.dark)
    }

    private func doSearch() {
        guard !isLoading else { return }
        isLoading = true
        onSearch(searchTitle, searchSinger) { newItems in
            self.items = newItems
            self.selectedIndex = newItems.isEmpty ? nil : 0
            self.previewLines = newItems.first?.Lyrics() ?? []
            self.activeLineId = nil
            self.isLoading = false
        }
    }

    private func updateActiveLine(position: Double) {
        guard let item = selectedItem else {
            activeLineId = nil
            return
        }

        let adjustedPosition = position + Double(item.offset) / 1000.0
        if let line = previewLines.first(where: { $0.beg <= adjustedPosition && adjustedPosition <= $0.end }) {
            activeLineId = line.id
        } else {
            activeLineId = nil
        }
    }

    private func scrollToActiveLine(proxy: ScrollViewProxy, force: Bool) {
        guard let activeLineId else { return }
        guard force || (!isUserScrolling && lyricsManager.isPlaying) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(activeLineId, anchor: .center)
        }
    }

    private func pauseAutoFollow() {
        isUserScrolling = true
        resumeFollowTask?.cancel()
        resumeFollowTask = nil
    }

    private func scheduleAutoFollowResume() {
        resumeFollowTask?.cancel()
        let task = DispatchWorkItem {
            isUserScrolling = false
        }
        resumeFollowTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }

    private var selectedItem: LyricResponseItem? {
        guard let selectedIndex,
              selectedIndex >= 0,
              selectedIndex < items.count else { return nil }
        return items[selectedIndex]
    }
}

struct LyricRow: View {
    let item: LyricResponseItem
    let isSelected: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .primary : .primary.opacity(0.9))
                        .lineLimit(1)

                    Text(item.type)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .cornerRadius(3)
                }

                Text(item.singer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : (isHovering ? Color.white.opacity(0.05) : Color.clear))
        )
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hover
            }
        }
    }
}
