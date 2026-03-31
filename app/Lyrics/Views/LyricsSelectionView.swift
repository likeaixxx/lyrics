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
            // ── Left Sidebar ──────────────────────────────────────────────
            VStack(spacing: 0) {
                // Search Header
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.teal)
                        Text("Search Lyrics")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    VStack(spacing: 8) {
                        SearchInputField(icon: "music.note", placeholder: "Song title", text: $searchTitle)
                        SearchInputField(icon: "person", placeholder: "Singer", text: $searchSinger)
                    }
                    .onSubmit { doSearch() }

                    Button(action: doSearch) {
                        HStack(spacing: 6) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.65)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 13))
                            }
                            Text(isLoading ? "Searching…" : "Search")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: isLoading
                                    ? [Color.teal.opacity(0.4), Color.teal.opacity(0.3)]
                                    : [Color.teal.opacity(0.85), Color.teal.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .shadow(color: Color.teal.opacity(0.3), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .animation(.easeInOut(duration: 0.15), value: isLoading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)

                Divider()
                    .background(Color.white.opacity(0.07))

                // Results
                Group {
                    if items.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: isLoading ? "ellipsis.circle" : "doc.text.magnifyingglass")
                                .font(.system(size: 34))
                                .foregroundStyle(.secondary.opacity(0.45))
                            Text(isLoading ? "Searching…" : "No results")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 3) {
                                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                    LyricRow(item: item, isSelected: selectedIndex == index)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedIndex = index
                                        }
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 230, idealWidth: 260, maxWidth: 320)
            .background(Color.black.opacity(0.28))

            // Thin divider
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 1)

            // ── Right Area (Previews & Action Bar) ─────────────────────────
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // ── Middle Preview ─────────────────────────────────────────────
                    VStack(spacing: 0) {
                        // Header bar
                ZStack {
                    Color.black.opacity(0.18)

                    HStack {
                        Text("Preview")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .padding(.leading, 18)
                        Spacer()
                    }

                    if let item = selectedItem {
                        HStack(spacing: 0) {
                            Text(item.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("  ·  ")
                                .foregroundStyle(.secondary.opacity(0.5))
                                .font(.system(size: 14))
                            Text(item.singer)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer().frame(width: 10)
                            ProviderBadge(type: item.type)
                        }
                        .padding(.horizontal, 80)
                    }
                }
                .frame(height: 52)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Lyrics content
                ZStack {
                    if let _ = selectedItem {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .center, spacing: 18) {
                                    ForEach(previewLines) { line in
                                        let isActive = line.id == activeLineId
                                        VStack(spacing: 5) {
                                            Text(line.text)
                                                .font(.system(
                                                    size: isActive ? 16 : 14,
                                                    weight: isActive ? .semibold : .regular,
                                                    design: .rounded
                                                ))
                                                .foregroundStyle(isActive ? AnyShapeStyle(Color.teal) : AnyShapeStyle(Color.primary.opacity(0.75)))
                                                .shadow(color: isActive ? Color.teal.opacity(0.5) : .clear, radius: 8)
                                                .multilineTextAlignment(.center)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .animation(.easeInOut(duration: 0.2), value: isActive)

                                            if !line.tran.isEmpty {
                                                Text(line.tran)
                                                    .font(.system(
                                                        size: isActive ? 13 : 12,
                                                        weight: isActive ? .regular : .light,
                                                        design: .rounded
                                                    ))
                                                    .foregroundStyle(isActive ? AnyShapeStyle(Color.teal.opacity(0.75)) : AnyShapeStyle(Color.secondary.opacity(0.6)))
                                                    .multilineTextAlignment(.center)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .animation(.easeInOut(duration: 0.2), value: isActive)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, isActive ? 4 : 0)
                                        .id(line.id)
                                    }
                                }
                                .padding(.vertical, 28)
                                .padding(.horizontal, 36)
                                .padding(.bottom, 64)
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
                                    .onChanged { _ in pauseAutoFollow() }
                                    .onEnded { _ in scheduleAutoFollowResume() }
                            )
                        }
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: "music.mic")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary.opacity(0.25))
                            Text("Select a track to preview")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary.opacity(0.45))
                            Text("Search and pick a result from the sidebar")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary.opacity(0.3))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Thin divider
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)

                // ── Right Raw LRC Preview ──────────────────────────────────────
                VStack(spacing: 0) {
                    // Header bar
                    ZStack {
                        Color.black.opacity(0.18)

                        HStack {
                            Text("Raw LRC")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary.opacity(0.5))
                                .padding(.leading, 18)
                            Spacer()
                        }
                    }
                    .frame(height: 52)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 1),
                        alignment: .bottom
                    )

                    // LRC Content
                    ZStack {
                        if let item = selectedItem {
                            ScrollView {
                                // rawLyrics() might need to be created if not present on item.
                                Text(item.rawLyrics())
                                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    .foregroundStyle(Color.primary.opacity(0.75))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 28)
                                    .padding(.horizontal, 24)
                            }
                        } else {
                            VStack(spacing: 14) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.secondary.opacity(0.25))
                                Text("Select a track to preview raw LRC")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.secondary.opacity(0.45))
                                Text("Raw format (e.g. [00:12.34]Lyric)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary.opacity(0.3))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(minWidth: 280, idealWidth: 340, maxWidth: 450)
                .background(Color.black.opacity(0.12))
            } // End of HStack for previews

            // Footer action bar
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)

                HStack(spacing: 10) {
                    Spacer()
                    Button("Cancel") {
                        NSApp.keyWindow?.close()
                    }
                    .buttonStyle(GhostButtonStyle())
                    .keyboardShortcut(.cancelAction)

                    Button("Use Lyric") {
                        if let item = selectedItem {
                            onSelect(item)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedItem == nil)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.18))
            }
        }
        .frame(minWidth: 1000, idealWidth: 1200, minHeight: 440, idealHeight: 560)
        .preferredColorScheme(.dark)
    }

    // MARK: - Logic (unchanged)

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

// MARK: - Sub-components

private struct SearchInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isFocused = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isFocused ? .teal : .secondary.opacity(0.6))
                .frame(width: 14)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit { isFocused = false }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(isFocused ? 0.09 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isFocused ? Color.teal.opacity(0.5) : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.1)) { isFocused = hover }
        }
    }
}

private struct ProviderBadge: View {
    let type: String

    var body: some View {
        Text(type.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.teal.opacity(0.18)))
            .foregroundStyle(Color.teal.opacity(0.9))
            .overlay(Capsule().strokeBorder(Color.teal.opacity(0.25), lineWidth: 0.5))
    }
}

private struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.1 : 0.06))
            )
            .foregroundStyle(.primary.opacity(0.85))
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: isEnabled
                                ? [Color.teal.opacity(configuration.isPressed ? 0.6 : 0.85), Color.teal.opacity(0.55)]
                                : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .foregroundStyle(isEnabled ? .white : .secondary)
            .shadow(color: isEnabled ? Color.teal.opacity(0.3) : .clear, radius: 5, y: 2)
    }
}

struct LyricRow: View {
    let item: LyricResponseItem
    let isSelected: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            // Leading indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(isSelected ? Color.teal : Color.clear)
                .frame(width: 3, height: 32)
                .animation(.easeInOut(duration: 0.15), value: isSelected)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))
                        .lineLimit(1)

                    Text(item.type.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.3)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(isSelected ? Color.teal.opacity(0.2) : Color.white.opacity(0.08)))
                        .foregroundStyle(isSelected ? Color.teal : Color.secondary)
                }

                Text(item.singer)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.teal)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected
                        ? Color.teal.opacity(0.08)
                        : (isHovering ? Color.white.opacity(0.04) : Color.clear)
                )
        )
        .contentShape(Rectangle())
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hover
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}
