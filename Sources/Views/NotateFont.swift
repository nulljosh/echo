import SwiftUI

/// Notate Sans, the app's typeface (fonts/). Same sizes and weights the views used with the system font.
extension Font {
    static func notate(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let face: String
        switch weight {
        case .bold, .heavy, .black: face = "NotateSans-Bold"
        case .semibold: face = "NotateSans-SemiBold"
        case .medium: face = "NotateSans-Medium"
        default: face = "NotateSans-Regular"
        }
        return .custom(face, size: size)
    }
}
