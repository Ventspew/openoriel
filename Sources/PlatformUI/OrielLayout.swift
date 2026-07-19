import SwiftUI

/// Shared layout helpers for iPhone / iPad / Mac chrome.
enum OrielLayout {
    static let phoneChromePadding: CGFloat = 14
    static let padChromePadding: CGFloat = 16
    static let navButtonSize: CGFloat = 40
    static let compactNavButtonSize: CGFloat = 36
    /// Visual weight for iPhone bottom toolbar icons (hit target stays ~44 via button style).
    static let phoneToolbarIconSize: CGFloat = 22
    static let startPageMaxWidthCompact: CGFloat = 560
    static let startPageMaxWidthRegular: CGFloat = 880
    static let startPageGutterCompact: CGFloat = 22
    static let startPageGutterRegular: CGFloat = 40
    static let profileChipMaxWidth: CGFloat = 120
}
