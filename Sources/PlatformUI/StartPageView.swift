import SwiftUI

struct StartPageView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tab: BrowserTab

    @State private var query = ""
    @State private var appeared = false
    @FocusState private var searchFocused: Bool

    private var activeEngine: SearchEngine {
        environment.settings.searchEngine
    }

    private var accent: Color {
        environment.settings.brandColor
    }

    private var stats: PrivacyStats {
        environment.privacyStats
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                hero
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)

                privacySummary

                if !environment.bookmarks.favorites.isEmpty {
                    section(title: "Favorites") {
                        linkRows(items: environment.bookmarks.favorites.map {
                            ($0.title, $0.urlString)
                        })
                    }
                }

                if !environment.history.recentSites.isEmpty {
                    section(title: "Recent") {
                        linkRows(items: environment.history.recentSites.prefix(6).map {
                            ($0.title, $0.urlString)
                        })
                    }
                }

                section(title: "Suggested") {
                    linkRows(items: [
                        ("openoriel.com", BrowserConstants.productWebsiteURL.absoluteString),
                        ("DuckDuckGo", "https://duckduckgo.com"),
                        ("Wikipedia", "https://wikipedia.org"),
                        ("Apple Developer", "https://developer.apple.com")
                    ])
                }

                footerLinks
                    .padding(.top, 4)

                Spacer(minLength: 48)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 10)
        }
        .background {
            OrielTheme.startPageBackground(
                accent: environment.settings.accentTheme,
                background: environment.settings.backgroundTheme,
                scheme: colorScheme
            )
        }
        .onAppear {
            if reduceMotion {
                appeared = true
                searchFocused = true
            } else {
                withAnimation(.easeOut(duration: 0.45)) {
                    appeared = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    searchFocused = true
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                OrielMark(size: 44)
                    .shadow(color: accent.opacity(0.18), radius: 12, y: 4)

                Text(BrowserConstants.productName)
                    .font(.system(size: 46, weight: .semibold, design: .serif))
                    .tracking(-1.0)
                    .foregroundStyle(.primary)

                Text("A calm view of the web.")
                    .font(.title3.weight(.regular))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            searchField

            Text("via \(activeEngine.displayName)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.8)

            enginePicker

            if activeEngine == .google {
                Button {
                    if let url = URL(string: "https://accounts.google.com/signin") {
                        tab.load(url)
                    }
                } label: {
                    Text("Sign in to Google")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(accent.opacity(0.14), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(accent.opacity(0.35), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(accent)
                .accessibilityHint("Opens Google Account sign-in in this tab.")
            }
        }
    }

    private var privacySummary: some View {
        Button {
            environment.showPrivacyShield = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Shields", systemImage: "hand.raised.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 10) {
                    privacyStat(
                        title: "Trackers",
                        session: stats.blockedRequestsSession,
                        lifetime: stats.blockedRequestsLifetime,
                        systemImage: "eye.slash"
                    )
                    privacyStat(
                        title: "Cookies",
                        session: stats.cookiesBlockedSession,
                        lifetime: stats.cookiesBlockedLifetime,
                        systemImage: "cookie"
                    )
                }

                HStack(spacing: 8) {
                    Image(systemName: environment.privacy.blockThirdPartyCookies ? "checkmark.shield.fill" : "shield")
                        .foregroundStyle(environment.privacy.blockThirdPartyCookies ? accent : Color.secondary)
                    Text(
                        environment.privacy.blockThirdPartyCookies
                            ? "Third-party cookies limited"
                            : "Third-party cookies allowed (better for sign-in)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .background(
                OrielTheme.surfaceFill(for: colorScheme),
                in: RoundedRectangle(cornerRadius: OrielTheme.sectionRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OrielTheme.sectionRadius, style: .continuous)
                    .strokeBorder(accent.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shields summary")
        .accessibilityHint("Opens Shields for tracker and cookie details")
        .accessibilityValue(
            "\(stats.blockedRequestsSession) trackers this session, \(stats.cookiesBlockedSession) cookies this session"
        )
    }

    private func privacyStat(
        title: String,
        session: Int,
        lifetime: Int,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            Text("\(session)")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text("this session · \(lifetime) all time")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(searchFocused ? accent : Color.secondary)

            TextField("Search or enter address", text: $query)
                .textFieldStyle(.plain)
                .font(.body)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.webSearch)
                .autocorrectionDisabled()
                #endif
                .focused($searchFocused)
                .onSubmit(submitSearch)
                .accessibilityLabel("Oriel search")
                .accessibilityHint("Searches with \(activeEngine.displayName) when the text is not a web address")

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            Button(action: submitSearch) {
                Text("Go")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.primary.opacity(0.06)
                        : accent.opacity(0.18),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.primary.opacity(0.08)
                                : accent.opacity(0.4),
                                lineWidth: 1
                            )
                    }
                    .foregroundStyle(
                        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.secondary
                        : accent
                    )
            }
            .buttonStyle(.plain)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Search")
        }
        .padding(.horizontal, 16)
        .frame(height: OrielTheme.searchFieldHeight)
        .background(
            OrielTheme.surfaceFill(for: colorScheme),
            in: RoundedRectangle(cornerRadius: OrielTheme.searchFieldRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OrielTheme.searchFieldRadius, style: .continuous)
                .strokeBorder(
                    searchFocused
                        ? accent.opacity(0.45)
                        : OrielTheme.hairline(for: colorScheme),
                    lineWidth: searchFocused ? 1.5 : 1
                )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06),
            radius: searchFocused ? 16 : 10,
            y: 4
        )
    }

    private var enginePicker: some View {
        HStack(spacing: 10) {
            ForEach(SearchEngine.allCases) { engine in
                let selected = activeEngine == engine
                Button {
                    environment.setSearchEngine(engine)
                    tab.searchEngine = engine
                } label: {
                    Text(engine.displayName)
                        .font(.caption.weight(selected ? .semibold : .medium))
                        .foregroundStyle(selected ? accent : Color.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            selected ? accent.opacity(0.14) : Color.primary.opacity(0.04),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    selected ? accent.opacity(0.35) : Color.primary.opacity(0.08),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityLabel("\(engine.displayName) search engine")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search engine")
    }

    private var footerLinks: some View {
        HStack(spacing: 12) {
            footerChip("Settings") {
                environment.showSettings = true
            }
            footerChip(BrowserConstants.productWebsiteHost) {
                tab.openProductSite()
            }
            footerChip(BrowserConstants.publisherName) {
                tab.openPublisherSite()
            }
            Spacer(minLength: 0)
        }
    }

    private func footerChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.05), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private func submitSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let engine = environment.settings.searchEngine
        tab.searchEngine = engine
        tab.load(URLParser.resolve(trimmed, searchEngine: engine))
        query = ""
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.9)
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(
                    OrielTheme.surfaceFill(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: OrielTheme.sectionRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: OrielTheme.sectionRadius, style: .continuous)
                        .strokeBorder(OrielTheme.hairline(for: colorScheme), lineWidth: 1)
                }
        }
    }

    private func linkRows(items: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    if let url = URL(string: item.1) {
                        tab.load(url)
                    }
                } label: {
                    HStack(spacing: 12) {
                        FaviconImage(pageURL: URL(string: item.1), size: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.0)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(item.1.replacingOccurrences(of: "https://", with: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < items.count - 1 {
                    Divider()
                        .opacity(0.4)
                }
            }
        }
    }
}
