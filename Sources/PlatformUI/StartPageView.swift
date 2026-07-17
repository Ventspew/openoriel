import SwiftUI

struct StartPageView: View {
    let tab: BrowserTab
    var onOpenPublisher: () -> Void

    private let suggestions: [(title: String, url: String)] = [
        ("Example", "https://example.com"),
        ("DuckDuckGo", "https://duckduckgo.com"),
        ("Wikipedia", "https://wikipedia.org"),
        ("Apple Developer", "https://developer.apple.com")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(BrowserConstants.productName)
                        .font(.largeTitle.weight(.bold))
                        .tracking(-0.5)

                    Text("A calm, private-minded browser.")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("Made by \(BrowserConstants.publisherName)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(OrielTheme.brandPrimary)
                        .padding(.top, 4)
                        .accessibilityAddTraits(.isStaticText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(suggestions, id: \.url) { item in
                        Button {
                            if let url = URL(string: item.url) {
                                tab.load(url)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: "globe")
                                    .font(.title2)
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(item.url.replacingOccurrences(of: "https://", with: ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(action: onOpenPublisher) {
                    Label("Visit \(BrowserConstants.publisherName)", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.12),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}
