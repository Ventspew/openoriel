import SwiftUI

enum OrielTheme {
    static let brandPrimary = Color("AccentColor")
    static let chromePadding: CGFloat = 10
    static let controlRadius: CGFloat = 12
    static let searchFieldRadius: CGFloat = 16
    static let searchFieldHeight: CGFloat = 54
    static let sectionRadius: CGFloat = 16
    static let hairlineOpacity: Double = 0.10

    /// Deep teal used when AccentColor asset is unavailable (previews / fallbacks).
    static let brandTeal = Color(red: 0.18, green: 0.38, blue: 0.42)
    static let brandTealSoft = Color(red: 0.52, green: 0.72, blue: 0.78)

    /// Quiet paper wash with a soft teal bloom — no neon gradients or glow.
    static var startPageBackground: some View {
        ZStack {
            Color(red: 0.965, green: 0.953, blue: 0.935)
            RadialGradient(
                colors: [
                    brandTealSoft.opacity(0.14),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            LinearGradient(
                colors: [
                    Color.black.opacity(0.025),
                    Color.clear,
                    Color.black.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    static var startPageBackgroundDark: some View {
        ZStack {
            Color(red: 0.10, green: 0.11, blue: 0.12)
            RadialGradient(
                colors: [
                    brandTeal.opacity(0.28),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 380
            )
            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    static func surfaceFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.72)
    }

    static func hairline(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(hairlineOpacity)
    }
}
