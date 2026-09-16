import Foundation

enum PerpsDecimalInput {
    static func sanitize(_ text: String) -> String {
        let allowed = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        let unified = allowed.replacingOccurrences(of: ",", with: ".")
        let parts = unified.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return unified }
        return parts[0] + "." + parts[1...].joined()
    }

    static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: ",", with: ".")
    }

    static func double(_ text: String) -> Double? {
        let posix = normalized(text).trimmingCharacters(in: .whitespaces)
        guard !posix.isEmpty,
              let value = Decimal(string: posix, locale: Locale(identifier: "en_US_POSIX"))
        else { return nil }
        return NSDecimalNumber(decimal: value).doubleValue
    }

    static func inputText(from value: Double) -> String {
        let formatted = String(format: "%.2f", value)
        if formatted.hasSuffix(".00") { return String(formatted.dropLast(3)) }
        return formatted
    }
}
