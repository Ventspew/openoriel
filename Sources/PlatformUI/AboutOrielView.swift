import SwiftUI

struct AboutOrielView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text(BrowserConstants.productName)
                    .font(.largeTitle.weight(.bold))

                Text("A native browser for Apple platforms.")
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text("Made by \(BrowserConstants.publisherName)")
                        .font(.headline)
                    Link(BrowserConstants.publisherURL.absoluteString, destination: BrowserConstants.publisherURL)
                        .font(.subheadline)
                }
                .padding(.top, 8)

                Text("Uses Apple’s WebKit framework. Privacy protections are limited by what WebKit and the OS expose — see docs/PRIVACY_LIMITATIONS.md in the project.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: 480)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
