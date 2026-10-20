import SwiftUI

/// The app's type: the system font (SF Pro), same sizes and weights everywhere.
extension Font {
    static func echo(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
