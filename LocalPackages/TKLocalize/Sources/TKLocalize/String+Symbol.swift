import Foundation

/// Typographic glyphs used while composing user-facing text. They live here because
/// TKLocalize is the only module every consumer (KeeperCore, TKUIKit, App, feature
/// packages) already depends on.
public extension String {
    enum Symbol {
        public static let minus = "\u{2212}"
        public static let plus = "\u{002B}"
        public static let shortSpace = "\u{2009}"
        public static let almostEqual = "\u{2248}"
        public static let middleDot = "\u{00B7}"
    }
}
