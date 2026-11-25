import SwiftUI

/// The app's type: the system font (SF Pro), same sizes and weights everywhere.
/// Each size maps to the iOS text style of that size, so text grows with Dynamic Type.
extension Font {
    static func echo(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        #if os(iOS)
        .system(style(for: size), weight: weight)
        #else
        .system(size: size, weight: weight) // ponytail: Mac text styles run smaller (body 13), keep the designed sizes
        #endif
    }

    #if os(iOS)
    private static func style(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<12: .caption2
        case ..<13: .caption
        case ..<15: .footnote
        case ..<16: .subheadline
        case ..<17: .callout
        case ..<20: .body
        case ..<22: .title3
        case ..<28: .title2
        case ..<34: .title
        default: .largeTitle
        }
    }
    #endif
}
