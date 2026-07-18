import SwiftUI
#if os(iOS)
import QuickLook
import UniformTypeIdentifiers
import UIKit
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct DownloadsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @State private var previewURL: URL?
    @State private var showFolderPicker = false
    #endif

    var body: some View {
        NavigationStack {
            Group {
                if environment.downloads.items.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Downloadable files from pages will appear here.")
                    )
                } else {
                    List {
                        ForEach(environment.downloads.items) { item in
                            downloadRow(item)
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: Binding(
                get: { previewURL.map(IdentifiableURL.init) },
                set: { previewURL = $0?.url }
            )) { item in
                QuickLookPreview(url: item.url)
                    .ignoresSafeArea()
            }
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    _ = url.startAccessingSecurityScopedResource()
                    environment.downloads.setDestinationFolder(url)
                }
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        #if os(macOS)
                        Button("Choose Download Folder…") {
                            pickFolderMac()
                        }
                        #else
                        Button("Choose Download Folder…") {
                            showFolderPicker = true
                        }
                        #endif
                        if environment.downloads.destinationFolderURL != nil {
                            Button("Reset to Default Folder") {
                                environment.downloads.setDestinationFolder(nil)
                            }
                        }
                        Divider()
                        Button("Clear Completed") {
                            environment.downloads.clearCompleted()
                        }
                        Button("Clear All", role: .destructive) {
                            environment.downloads.clearAll()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Image(systemName: "folder")
                    Text("Save to \(environment.downloads.destinationDisplayName)")
                        .lineLimit(1)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
    }

    @ViewBuilder
    private func downloadRow(_ item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.fileName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(statusText(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if item.state == .downloading || item.state == .paused {
                ProgressView(value: item.progress)
                if item.totalBytes > 0 {
                    Text(byteLabel(written: item.bytesWritten, total: item.totalBytes))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let error = item.errorMessage, item.state == .failed || item.state == .cancelled {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack {
                if item.state == .downloading {
                    Button("Pause") { environment.downloads.pause(item.id) }
                    Button("Cancel") { environment.downloads.cancel(item.id) }
                }
                if item.state == .paused {
                    Button("Resume") { environment.downloads.resume(item.id) }
                    Button("Cancel") { environment.downloads.cancel(item.id) }
                }
                if item.state == .queued {
                    Button("Cancel") { environment.downloads.cancel(item.id) }
                }
                if item.state == .failed || item.state == .cancelled {
                    Button("Retry") { environment.downloads.retry(item.id) }
                }
                #if os(macOS)
                if item.state == .completed, let url = item.destinationURL {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                #elseif os(iOS)
                if item.state == .completed, let url = item.destinationURL {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button("Open") {
                        previewURL = url
                    }
                }
                #endif
                Spacer()
                Button("Remove", role: .destructive) {
                    environment.downloads.remove(item.id)
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private func statusText(_ item: DownloadItem) -> String {
        switch item.state {
        case .queued: return "Queued"
        case .downloading: return "Downloading…"
        case .paused: return "Paused"
        case .completed: return "Done"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    private func byteLabel(written: Int64, total: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: written)) / \(formatter.string(fromByteCount: total))"
    }

    #if os(macOS)
    private func pickFolderMac() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            environment.downloads.setDestinationFolder(url)
        }
    }
    #endif
}

#if os(iOS)
private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}
#endif
