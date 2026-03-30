import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var lyricsViewModel: LyricsViewModel

    // Persist font preference
    @AppStorage("lyricFontName") private var fontName: String = "PingFang SC"

    // Connection test state
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?

    // Get all available system fonts
    private var availableFonts: [String] {
        let fontManager = NSFontManager.shared
        let fontFamilies = fontManager.availableFontFamilies.sorted()

        // Prioritize common and recommended fonts
        let recommendedFonts = [
            "PingFang SC",
            "SF Pro",
            "SF Mono",
            "Menlo",
            "Helvetica Neue",
            "Arial",
            "Courier New"
        ]

        // Combine recommended fonts with all available fonts, removing duplicates
        var allFonts = recommendedFonts
        for family in fontFamilies {
            if !allFonts.contains(family) {
                allFonts.append(family)
            }
        }

        return allFonts
    }

    var body: some View {
        TabView {
            // General Settings (Font)
            Form {
                Section(header: Text("Appearance")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Font Family")
                            .font(.headline)

                        Picker("", selection: $fontName) {
                            ForEach(availableFonts, id: \.self) { font in
                                Text(font).tag(font)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: fontName) { _ in
                            // Force notification to update menu bar
                            NotificationCenter.default.post(
                                name: UserDefaults.didChangeNotification,
                                object: nil
                            )
                        }

                        Text("Selected: \(fontName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Preview
                    VStack(alignment: .leading) {
                        Text("Preview:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("The quick brown fox jumps over the lazy dog.\n测试中文字体显示效果")
                            .font(.custom(fontName, size: 14))
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gear")
            }

            // Network Settings (Host)
            Form {
                Section(header: Text("Network")) {
                    TextField("API Host", text: $lyricsViewModel.host)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text("Current Host: \(lyricsViewModel.host)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Connection Test")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: {
                                testConnection()
                            }) {
                                HStack {
                                    if isTestingConnection {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "network")
                                    }
                                    Text(isTestingConnection ? "Testing..." : "Test Connection")
                                }
                            }
                            .disabled(isTestingConnection)
                        }

                        if let result = connectionTestResult {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(result.contains("Success") ? .green : .red)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .padding()
            .tabItem {
                Label("Network", systemImage: "network")
            }
        }
        .frame(width: 500, height: 400)
    }

    // MARK: - Connection Test

    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil

        guard let url = URL(string: lyricsViewModel.host) else {
            connectionTestResult = "Error: Invalid host URL"
            isTestingConnection = false
            return
        }

        // Create a simple health check request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isTestingConnection = false

                if let error = error {
                    connectionTestResult = "Error: \(error.localizedDescription)"
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 404 {
                        // 404 is also acceptable as it means server is reachable
                        connectionTestResult = "✓ Success: Server is reachable (Status: \(httpResponse.statusCode))"
                    } else {
                        connectionTestResult = "Warning: Server responded with status \(httpResponse.statusCode)"
                    }
                } else {
                    connectionTestResult = "✓ Success: Connection established"
                }
            }
        }.resume()
    }
}
