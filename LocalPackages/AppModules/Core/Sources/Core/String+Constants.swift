import Foundation

public extension String {
    static let secureModeValueShort = "* * *"
    static let secureModeValueLong = "* * * *"

    enum Symbol {
        public static let minus = "\u{2212}"
        public static let plus = "\u{002B}"
        public static let shortSpace = "\u{2009}"
        public static let almostEqual = "\u{2248}"
        public static let middleDot = "\u{00B7}"
    }
}
