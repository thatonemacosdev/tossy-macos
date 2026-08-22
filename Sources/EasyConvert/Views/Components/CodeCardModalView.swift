import SwiftUI

struct CodeCardModalView: View {
    var initialCode: String = ""
    var initialFileName: String = "snippet.swift"
    @Environment(\.dismiss) private var dismiss
    
    @State private var codeText: String = """
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello, Tossy 2.0 Titanium!")
            .font(.largeTitle.bold())
            .foregroundStyle(.tint)
    }
}
"""
    @State private var title: String = "ContentView.swift"
    @State private var selectedTheme: CodeCardTheme = .darkTitanium
    @State private var selectedLanguage: String = "Swift"
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String?
    @State private var outputURL: URL?
    
    let languages = ["Swift", "Python", "TypeScript", "JavaScript", "Rust", "Go", "JSON", "HTML", "CSS", "Markdown", "Shell"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "curlybraces.square.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Code Card Studio (Carbon Style)")
                        .font(.headline)
                    Text("Export syntax-highlighted code cards with macOS window chrome")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            VStack(spacing: 12) {
                // Controls Bar
                HStack(spacing: 16) {
                    TextField("Card Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                    
                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(languages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .frame(width: 140)
                    
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(CodeCardTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .frame(width: 160)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                // Code Editor / Input
                TextEditor(text: $codeText)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal)
            }
            
            Divider()
                .padding(.top, 12)
            
            // Footer
            HStack {
                if isProcessing {
                    ProgressView().controlSize(.small)
                    Text("Rendering PNG card...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let outputURL {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Export Code Card PNG") {
                    exportCodeCard()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || codeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 680, minHeight: 520)
        .onAppear {
            if !initialCode.isEmpty {
                codeText = initialCode
                title = initialFileName
            }
        }
    }
    
    private func exportCodeCard() {
        isProcessing = true
        statusMessage = "Exporting code card..."
        
        let downloadsFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let safeName = title.replacingOccurrences(of: "/", with: "_").trimmingCharacters(in: .whitespacesAndNewlines)
        let cardName = safeName.isEmpty ? "code_card" : "\(safeName)_card"
        let desired = downloadsFolder.appendingPathComponent("\(cardName).png")
        let safeDestination = OutputNaming.uniqueDestinationURL(desiredURL: desired)
        
        Task {
            do {
                let res = try await MarkdownCodeExportService.shared.renderCodeCard(
                    sourceCode: codeText,
                    language: selectedLanguage,
                    title: title,
                    theme: selectedTheme,
                    destination: safeDestination
                )
                await MainActor.run {
                    self.outputURL = res
                    self.statusMessage = "Exported to \(res.lastPathComponent)"
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Error: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
}
