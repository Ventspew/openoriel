import SwiftUI

struct FindInPageBar: View {
    @Binding var query: String
    var matchCount: Int?
    var matchFound: Bool
    var onSubmit: () -> Void
    var onNext: () -> Void
    var onPrevious: () -> Void
    var onClose: () -> Void

    private var statusText: String? {
        guard !query.isEmpty else { return nil }
        if let matchCount {
            if matchCount == 0 { return "No matches" }
            if matchCount == 1 { return "1 match" }
            return "\(matchCount) matches"
        }
        return matchFound ? "Found" : nil
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Find in page", text: $query)
                .textFieldStyle(.plain)
                .onSubmit(onSubmit)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif

            if let statusText {
                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(matchCount == 0 ? Color.orange : Color.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            Button(action: onPrevious) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(query.isEmpty || matchCount == 0)
            .accessibilityLabel("Previous match")

            Button(action: onNext) {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(query.isEmpty || matchCount == 0)
            .accessibilityLabel("Next match")

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Close find")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
