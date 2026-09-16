import Foundation

public extension String {
    static let secureModeValueShort = "* * *"
    static let secureModeValueLong = "* * * *"

    func normalizeTetherSymbol() -> String {
        replacingOccurrences(of: "₮", with: "T")
    }
}
