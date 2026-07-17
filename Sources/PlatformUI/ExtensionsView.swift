import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct ExtensionsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var isInstalling = false

    var body: some View {
        NavigationStack {
            Group {
                if environment.extensions.isSupported {
                    supportedBody
                } else {
                    unsupportedBody
                }
            }
            .navigationTitle("Extensions")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                #if os(macOS)
                if environment.extensions.isSupported {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Install…") {
                            Task { await pickAndInstall() }
                        }
                        .disabled(isInstalling)
                    }
                }
                #endif
            }
            #if os(macOS)
            .frame(minWidth: 520, idealWidth: 580, minHeight: 420, idealHeight: 560)
            #endif
        }
    }

    @ViewBuilder
    private var supportedBody: some View {
        List {
            Section {
                Text("Install Manifest V2/V3 extensions from a folder, .zip, or .crx. Browse the Chrome Web Store for packages, then install the downloaded file here — one-click store install is not available outside Chrome.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Chrome Web Store") {
                Button {
                    environment.openURLInNewTab(BrowserConstants.chromeWebStoreURL)
                    dismiss()
                } label: {
                    Label("Browse Chrome Web Store", systemImage: "safari")
                }
            }

            Section("Installed") {
                if environment.extensions.extensions.isEmpty {
                    Text("No extensions installed yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(environment.extensions.extensions) { item in
                        extensionRow(item)
                    }
                }
            }

            if let error = environment.extensions.lastError {
                Section("Status") {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #endif
    }

    private func extensionRow(_ item: InstalledExtensionInfo) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.body.weight(.semibold))
                Text("v\(item.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(
                "Enabled",
                isOn: Binding(
                    get: { item.isEnabled },
                    set: { newValue in
                        Task { await environment.extensions.setEnabled(newValue, id: item.id) }
                    }
                )
            )
            .labelsHidden()
            .accessibilityLabel("Enabled")

            Button(role: .destructive) {
                Task { await environment.extensions.remove(id: item.id) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove \(item.displayName)")
        }
    }

    private var unsupportedBody: some View {
        ContentUnavailableView {
            Label("Extensions unavailable", systemImage: "puzzlepiece.extension")
        } description: {
            Text(environment.extensions.lastError
                  ?? "Web extensions are not available on this platform.")
        } actions: {
            Button("Browse Chrome Web Store") {
                environment.openURLInNewTab(BrowserConstants.chromeWebStoreURL)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    #if os(macOS)
    private func pickAndInstall() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .zip,
            UTType(filenameExtension: "crx") ?? .data,
            .folder
        ]
        panel.message = "Choose an unpacked extension folder, .zip, or .crx package"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isInstalling = true
        defer { isInstalling = false }
        await environment.extensions.installFromPackage(at: url)
    }
    #endif
}
