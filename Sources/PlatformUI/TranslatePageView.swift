import SwiftUI

struct TranslatePageView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var targetLanguage = "en"
    @State private var status = "Ready"
    @State private var isWorking = false

    private let languages: [(String, String)] = [
        ("en", "English"),
        ("nl", "Dutch"),
        ("de", "German"),
        ("fr", "French"),
        ("es", "Spanish"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("pl", "Polish"),
        ("sv", "Swedish"),
        ("da", "Danish")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Translate to", selection: $targetLanguage) {
                    ForEach(languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(isWorking ? "Translating…" : "Translate Page") {
                    Task { await translate() }
                }
                .disabled(isWorking || environment.activeTab?.isShowingStartPage == true)
            }
            .navigationTitle("Translate")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func translate() async {
        guard let tab = environment.activeTab, let webView = tab.webView else { return }
        isWorking = true
        status = "Extracting text…"
        do {
            let raw: Any? = try await withCheckedThrowingContinuation { cont in
                webView.evaluateJavaScript(PageTranslator.extractTextScript, in: nil, in: .page) { result in
                    switch result {
                    case .success(let value): cont.resume(returning: value)
                    case .failure(let error): cont.resume(throwing: error)
                    }
                }
            }
            let blob = (raw as? String) ?? ""
            let chunks = blob.components(separatedBy: "\n<<<ORIEL>>>\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            status = "Translating \(min(chunks.count, 40)) snippets…"
            let map = await PageTranslator.translateChunks(Array(chunks.prefix(40)), target: targetLanguage)
            guard !map.isEmpty else {
                status = "No translation returned. Try again later."
                isWorking = false
                return
            }
            let script = PageTranslator.applyTranslationScript(replacements: map)
            _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Any?, Error>) in
                webView.evaluateJavaScript(script, in: nil, in: .page) { result in
                    switch result {
                    case .success(let value): cont.resume(returning: value)
                    case .failure(let error): cont.resume(throwing: error)
                    }
                }
            }
            status = "Translated \(map.count) snippets."
        } catch {
            status = "Translation failed."
        }
        isWorking = false
    }
}
