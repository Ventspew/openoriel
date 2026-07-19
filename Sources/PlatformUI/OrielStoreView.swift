import SwiftUI

/// Universal extension/theme browser — one search across Chrome, Firefox, and Safari.
/// Preferred over opening the store websites (iPhone, iPad, and Mac).
struct OrielStoreView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var kind: ExtensionStoreItem.Kind = .extension
    @State private var query = ""
    @State private var listings: [UnifiedStoreListing] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var installingID: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var installHint: String?

    /// When true (sheet presentation), show a Done button. Hidden inside Extensions navigation.
    var showsDoneButton: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            kindPicker
            searchField
            content
        }
        .navigationTitle("Oriel Store")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task(id: kind.rawValue) {
            await reload(debounce: false)
        }
        .onChange(of: query) { _, _ in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                await reload(debounce: true)
            }
        }
        .onAppear {
            #if os(macOS)
            environment.extensions.refreshSafariCandidates()
            #endif
        }
        .alert("Safari extension", isPresented: Binding(
            get: { installHint != nil },
            set: { if !$0 { installHint = nil } }
        )) {
            Button("OK", role: .cancel) { installHint = nil }
        } message: {
            Text(installHint ?? "")
        }
    }

    private var kindPicker: some View {
        Picker("Kind", selection: $kind) {
            Text("Extensions").tag(ExtensionStoreItem.Kind.extension)
            Text("Themes").tag(ExtensionStoreItem.Kind.theme)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                kind == .theme ? "Search themes" : "Search extensions",
                text: $query
            )
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.webSearch)
            #endif
            .autocorrectionDisabled()
            .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && listings.isEmpty {
            Spacer()
            ProgressView("Loading catalog…")
            Spacer()
        } else if let errorMessage, listings.isEmpty {
            Spacer()
            ContentUnavailableView(
                "Couldn’t load store",
                systemImage: "wifi.exclamationmark",
                description: Text(errorMessage)
            )
            Button("Retry") {
                Task { await reload(debounce: false) }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        } else if listings.isEmpty {
            Spacer()
            ContentUnavailableView(
                "No results",
                systemImage: "puzzlepiece.extension",
                description: Text("Try another search across Chrome, Firefox, and Safari.")
            )
            Spacer()
        } else {
            List {
                Section {
                    Text(footerBlurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(listings) { listing in
                        storeRow(listing)
                    }
                } header: {
                    Text(query.isEmpty ? "Popular" : "Results")
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
        }
    }

    private var footerBlurb: String {
        "One catalog for Chrome, Firefox, and Safari. Oriel picks the best available source when you tap Add — same install pipeline on Mac, iPhone, and iPad."
    }

    private func storeRow(_ listing: UnifiedStoreListing) -> some View {
        HStack(alignment: .top, spacing: 12) {
            iconView(for: listing)
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if !listing.summary.isEmpty {
                    Text(listing.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                sourceChips(for: listing)
                if let installed = installedSource(for: listing) {
                    Text(installed.installedFromLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                } else if let rating = listing.rating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Button {
                Task { await install(listing) }
            } label: {
                if installingID == listing.id || environment.extensions.isInstallingFromStore {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(installedSource(for: listing) != nil ? "Open" : "Add")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(installingID != nil || environment.extensions.isInstallingFromStore)
        }
        .padding(.vertical, 4)
    }

    private func sourceChips(for listing: UnifiedStoreListing) -> some View {
        let available = Set(listing.availableSources)
        return HStack(spacing: 6) {
            ForEach(ExtensionStoreItem.Source.allCases, id: \.self) { source in
                let on = available.contains(source)
                HStack(spacing: 3) {
                    Image(systemName: on ? "checkmark" : "minus")
                        .font(.caption2.weight(.bold))
                    Text(source.displayName)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(on ? Color.primary : Color.secondary.opacity(0.55))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    (on ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08)),
                    in: Capsule()
                )
                .accessibilityLabel("\(source.displayName) \(on ? "available" : "not available")")
            }
        }
    }

    @ViewBuilder
    private func iconView(for listing: UnifiedStoreListing) -> some View {
        let placeholder = Image(systemName: listing.kind == .theme ? "paintpalette.fill" : "puzzlepiece.extension.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        if let url = listing.iconURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private func installedSource(for listing: UnifiedStoreListing) -> ExtensionStoreItem.Source? {
        for offer in listing.offers {
            switch offer.source {
            case .chrome:
                if environment.extensions.isInstalledFromChromeWebStore(extensionID: offer.storeIdentifier) {
                    return .chrome
                }
            case .firefox:
                if environment.extensions.isInstalledFromFirefoxAMO(slug: offer.storeIdentifier) {
                    return .firefox
                }
            case .safari:
                if environment.extensions.isInstalledFromSafari(bundleIdentifier: offer.storeIdentifier) {
                    return .safari
                }
            }
        }
        // Name match against installed extensions (file/zip installs without store ids).
        let key = ExtensionStoreCatalog.normalizationKey(forName: listing.name)
        if environment.extensions.extensions.contains(where: {
            ExtensionStoreCatalog.normalizationKey(forName: $0.displayName) == key
                && $0.chromeStoreID == nil
                && $0.firefoxSlug == nil
        }) {
            return listing.offers.contains(where: { $0.source == .safari }) ? .safari : listing.offers.first?.source
        }
        return nil
    }

    /// Prefer an already-installed source; otherwise the catalog’s ranked preferred offer.
    private func offerToInstall(for listing: UnifiedStoreListing) -> ExtensionStoreItem? {
        if let installed = installedSource(for: listing),
           let offer = listing.offers.first(where: { $0.source == installed }) {
            return offer
        }
        // Skip Safari “known:” placeholders that aren’t a real local .appex.
        if let preferred = listing.preferredOffer {
            if preferred.source == .safari, preferred.storeIdentifier.hasPrefix("known:") {
                return listing.offers.first(where: { $0.source != .safari })
            }
            return preferred
        }
        return listing.offers.first
    }

    @MainActor
    private func reload(debounce: Bool) async {
        if !debounce {
            isLoading = true
        }
        errorMessage = nil
        let requestedKind = kind
        let requestedQuery = query
        let safari = environment.extensions.safariCandidates
        let result = await ExtensionStoreCatalog.searchUniversal(
            query: requestedQuery,
            kind: requestedKind,
            limit: 40,
            safariCandidates: safari
        )
        guard !Task.isCancelled else { return }
        guard requestedKind == kind, requestedQuery == query else { return }
        listings = result
        // Empty search results are fine; only show an error when the popular list is blank.
        if result.isEmpty && requestedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Couldn’t load the catalog. Check your connection and try again."
        } else {
            errorMessage = nil
        }
        isLoading = false
    }

    @MainActor
    private func install(_ listing: UnifiedStoreListing) async {
        if installedSource(for: listing) != nil {
            dismiss()
            environment.showExtensions = true
            return
        }
        guard let offer = offerToInstall(for: listing) else { return }
        installingID = listing.id
        defer { installingID = nil }
        switch offer.source {
        case .chrome:
            await environment.extensions.installFromChromeWebStore(extensionID: offer.storeIdentifier)
        case .firefox:
            await environment.extensions.installFromFirefoxAMO(slugOrID: offer.storeIdentifier)
        case .safari:
            if offer.storeIdentifier.hasPrefix("known:") {
                installHint =
                    "This extension is also published for Safari. On Mac, install its Safari app, then use Extensions → Scan Safari extensions to import it into Oriel."
            } else if let candidate = environment.extensions.safariCandidates.first(where: {
                $0.bundleIdentifier == offer.storeIdentifier
            }) {
                await environment.extensions.installSafariCandidate(candidate)
            } else if let url = offer.storeURL {
                await environment.extensions.installFromPackage(at: url)
            } else {
                installHint = "That Safari extension isn’t available to import on this device yet."
            }
        }
        listings = listings
    }
}
