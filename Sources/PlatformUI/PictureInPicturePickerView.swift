import SwiftUI

struct PictureInPicturePickerView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var videos: [[String: Any]] = []
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Group {
                if !didLoad {
                    ProgressView("Looking for videos…")
                } else if videos.isEmpty {
                    ContentUnavailableView(
                        "No Videos",
                        systemImage: "pip",
                        description: Text("Play a video on this page, then try again.")
                    )
                } else {
                    List {
                        Button {
                            environment.activeTab?.togglePictureInPicture()
                            dismiss()
                        } label: {
                            Label("Best match (playing or largest)", systemImage: "sparkles")
                        }
                        ForEach(Array(videos.enumerated()), id: \.offset) { _, video in
                            let index = video["index"] as? Int ?? 0
                            let label = video["label"] as? String ?? "Video \(index + 1)"
                            Button {
                                environment.activeTab?.togglePictureInPicture(at: index)
                                dismiss()
                            } label: {
                                Text(label)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Picture in Picture")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadVideos()
            }
        }
    }

    @MainActor
    private func loadVideos() async {
        guard let tab = environment.activeTab else {
            didLoad = true
            return
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            tab.listPictureInPictureVideos { list in
                Task { @MainActor in
                    videos = list
                    didLoad = true
                    cont.resume()
                }
            }
        }
    }
}
