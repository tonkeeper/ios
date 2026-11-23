import CoreText
import UIKit

public enum TKAmountDigits {
    public static var decimalSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }

    public static var systemLocale: Locale {
        UserDefaults.standard.string(forKey: "AppleLocale").map(Locale.init(identifier:)) ?? .current
    }

    static func keyTitle(_ key: String, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        guard formatter.string(from: 0) != "0" else { return key }
        guard let digit = Int(key) else { return formatter.decimalSeparator ?? key }
        return formatter.string(from: NSNumber(value: digit)) ?? key
    }

    public static func normalized(_ text: String, allowsSign: Bool = false) -> String? {
        var result = ""
        var hasSeparator = false
        for character in text where !character.isWhitespace {
            if let digit = character.asciiDigit {
                result.append(digit)
            } else if character.isDecimalSeparator {
                guard !result.hasSuffix(".") else { continue }
                guard !hasSeparator else { return nil }
                hasSeparator = true
                result.append(".")
            } else if allowsSign, result.isEmpty, character.isSign {
                result.append(character == "+" ? "+" : "-")
            } else {
                return nil
            }
        }
        return result
    }

    public static func localized(_ text: String, decimalSeparator: String = decimalSeparator) -> String {
        let separators = text.filter(\.isDecimalSeparator)
        guard separators.count == 1 else { return text }
        return text.replacingOccurrences(of: separators, with: decimalSeparator)
    }

    public static func grouped(_ text: String) -> String {
        let plain = ungrouped(text)
        let start = plain.firstIndex { $0 != "-" } ?? plain.endIndex
        guard start < plain.endIndex, plain[start].isAmountDigit else { return plain }
        let end = plain[start...].firstIndex { !$0.isAmountDigit } ?? plain.endIndex
        let integer = plain[start ..< end]
        var result = String(plain[..<start])
        for (offset, digit) in integer.enumerated() {
            if offset > 0, (integer.count - offset).isMultiple(of: 3) {
                result.append(" ")
            }
            result.append(digit)
        }
        return result + plain[end...]
    }

    public static func ungrouped(_ text: String) -> String {
        text.filter { !$0.isGroupingSpace }
    }

    public static func offset(afterCharacters count: Int, in grouped: String) -> Int {
        guard count > 0 else { return 0 }
        var passed = 0
        var offset = 0
        for character in grouped {
            offset += character.utf16.count
            if !character.isGroupingSpace {
                passed += 1
                if passed == count { return offset }
            }
        }
        return offset
    }
}

struct TKAmountGlyph {
    let id: String
    let character: Character
    let x: CGFloat
}

extension TKAmountDigits {
    private static let roundingSlack: CGFloat = 1

    static func fits(_ text: String, font: UIFont, width: CGFloat) -> Bool {
        glyphs(text, font: font).width <= width + roundingSlack
    }

    static func glyphs(_ text: String, font: UIFont) -> (glyphs: [TKAmountGlyph], width: CGFloat) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
        let width = ceil(CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
        var utf16Offset = 0
        var integerDigits = 0
        var fractionDigits: Int?
        var glyphs: [TKAmountGlyph] = []
        for (index, character) in text.enumerated() {
            let id: String
            if character.isAmountDigit {
                if let fraction = fractionDigits {
                    id = "f\(fraction):\(character)"
                    fractionDigits = fraction + 1
                } else {
                    id = "i\(integerDigits):\(character)"
                    integerDigits += 1
                }
            } else if character.isGroupingSpace {
                id = "g\(integerDigits)"
            } else if fractionDigits == nil, integerDigits > 0 || character != "-" {
                id = "d"
                fractionDigits = 0
            } else {
                id = "o\(index):\(character)"
            }
            glyphs.append(TKAmountGlyph(id: id, character: character, x: CTLineGetOffsetForStringIndex(line, utf16Offset, nil)))
            utf16Offset += character.utf16.count
        }
        return (glyphs, width)
    }
}

private extension Character {
    var isAmountDigit: Bool {
        ("0" ... "9").contains(self)
    }

    var asciiDigit: Character? {
        guard unicodeScalars.count == 1,
              unicodeScalars.first?.properties.numericType == .decimal,
              let value = wholeNumberValue
        else { return nil }
        return Character(String(value))
    }

    var isDecimalSeparator: Bool {
        switch self {
        case ".", ",", "\u{066B}", "\u{060C}", "\u{FF0E}": true
        default: String(self) == TKAmountDigits.decimalSeparator
        }
    }

    var isSign: Bool {
        self == "+" || self == "-" || self == "−"
    }

    var isGroupingSpace: Bool {
        switch self {
        case " ", "\u{00A0}", "\u{2007}", "\u{2009}", "\u{202F}": true
        default: false
        }
    }
}
