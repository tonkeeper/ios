import Foundation
import UIKit

/// UIColor is reference-typed and imported without Sendable guarantees, but this wrapper is
/// used as an immutable RGBA value container throughout the public options surface.
public final class ChartColor: UIColor, @unchecked Sendable {
    public convenience init(_ color: UIColor) {
        self.init(colorComponents: color.components)
    }

    convenience init(colorComponents: ColorComponents) {
        self.init(
            red: colorComponents.red,
            green: colorComponents.green,
            blue: colorComponents.blue,
            alpha: colorComponents.alpha
        )
    }

    public convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - Codable

extension ChartColor: Codable {
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - RawRepresentable

extension ChartColor: RawRepresentable {
    public var rawValue: String {
        let components = self.components
        return "rgba(\(components.red255), \(components.green255), \(components.blue255), \(components.alpha))"
    }

    public convenience init(rawValue: String) {
        guard let colorComponents = ColorComponents.from(string: rawValue) else {
            self.init(colorComponents: .clear)
            return
        }
        self.init(
            red: colorComponents.red,
            green: colorComponents.green,
            blue: colorComponents.blue,
            alpha: colorComponents.alpha
        )
    }
}

// MARK: - ExpressibleByStringLiteral

extension ChartColor: ExpressibleByStringLiteral {
    public convenience init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

// MARK: -

struct ColorComponents {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    var red255: Int {
        Int(colorComponent: red)
    }

    var green255: Int {
        Int(colorComponent: green)
    }

    var blue255: Int {
        Int(colorComponent: blue)
    }

    init(
        red: CGFloat = 0,
        green: CGFloat = 0,
        blue: CGFloat = 0,
        alpha: CGFloat = 0
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

// MARK: -

extension ColorComponents {
    static func from(string: String) -> ColorComponents? {
        let range = NSRange(string.startIndex ..< string.endIndex, in: string)

        if let rgba = parse(rgbaString: string, range: range) {
            return rgba
        } else if let rgb = parse(rgbString: string, range: range) {
            return rgb
        } else if let hex = parse(hexString: string) {
            return hex
        }

        return nil
    }

    static func parse(rgbaString: String, range: NSRange) -> ColorComponents? {
        guard let match = NSRegularExpression.rgba?.firstMatch(in: rgbaString, range: range) else { return nil }
        guard match.numberOfRanges >= 5 else { return nil }

        guard let red = parse(componentMatch: match, at: 1, in: rgbaString) else { return nil }
        guard let green = parse(componentMatch: match, at: 2, in: rgbaString) else { return nil }
        guard let blue = parse(componentMatch: match, at: 3, in: rgbaString) else { return nil }
        guard let alpha = parse(componentMatch: match, at: 4, in: rgbaString) else { return nil }

        return ColorComponents(
            red: red / 255.0,
            green: green / 255.0,
            blue: blue / 255.0,
            alpha: alpha
        )
    }

    static func parse(rgbString: String, range: NSRange) -> ColorComponents? {
        guard let match = NSRegularExpression.rgb?.firstMatch(in: rgbString, range: range) else { return nil }
        guard match.numberOfRanges >= 4 else { return nil }

        guard let red = parse(componentMatch: match, at: 1, in: rgbString) else { return nil }
        guard let green = parse(componentMatch: match, at: 2, in: rgbString) else { return nil }
        guard let blue = parse(componentMatch: match, at: 3, in: rgbString) else { return nil }

        return ColorComponents(
            red: red / 255.0,
            green: green / 255.0,
            blue: blue / 255.0,
            alpha: 1.0
        )
    }

    static func parse(componentMatch: NSTextCheckingResult, at index: Int, in string: String) -> CGFloat? {
        guard let range = Range(componentMatch.range(at: index), in: string) else { return nil }
        guard let value = Float(string[range]) else { return nil }
        return CGFloat(value)
    }

    static func parse(hexString: String) -> ColorComponents? {
        if hexString.hasPrefix("#") {
            return parse(hexString: String(hexString.dropFirst()))
        }

        let scanner = Scanner(string: hexString)
        var hexNumber: UInt64 = 0

        guard scanner.scanHexInt64(&hexNumber) else { return nil }

        switch hexString.count {
        case 3: return ColorComponents.from(hex3: hexNumber) // #RGB
        case 4: return ColorComponents.from(hex4: hexNumber) // #RGBA
        case 6: return ColorComponents.from(hex6: hexNumber) // #RRGGBB
        case 8: return ColorComponents.from(hex8: hexNumber) // #RRGGBBAA
        default: return nil
        }
    }

    /// #RGB hex
    static func from(hex3: UInt64) -> ColorComponents {
        return ColorComponents(
            red: CGFloat((hex3 & 0xF00) >> 8) / 15,
            green: CGFloat((hex3 & 0x0F0) >> 4) / 15,
            blue: CGFloat(hex3 & 0x00F) / 15,
            alpha: 1
        )
    }

    /// #RGBA hex
    static func from(hex4: UInt64) -> ColorComponents {
        return ColorComponents(
            red: CGFloat((hex4 & 0xF000) >> 12) / 15,
            green: CGFloat((hex4 & 0x0F00) >> 8) / 15,
            blue: CGFloat((hex4 & 0x00F0) >> 4) / 15,
            alpha: CGFloat(hex4 & 0x000F) / 15
        )
    }

    /// #RRGGBB hex
    static func from(hex6: UInt64) -> ColorComponents {
        return ColorComponents(
            red: CGFloat((hex6 & 0xFF0000) >> 16) / 255,
            green: CGFloat((hex6 & 0x00FF00) >> 8) / 255,
            blue: CGFloat(hex6 & 0x0000FF) / 255,
            alpha: 1
        )
    }

    /// #RRGGBBAA hex
    static func from(hex8: UInt64) -> ColorComponents {
        return ColorComponents(
            red: CGFloat((hex8 & 0xFF00_0000) >> 24) / 255,
            green: CGFloat((hex8 & 0x00FF_0000) >> 16) / 255,
            blue: CGFloat((hex8 & 0x0000_FF00) >> 8) / 255,
            alpha: CGFloat(hex8 & 0x0000_00FF) / 255
        )
    }
}

// MARK: -

extension ColorComponents {
    static var clear: ColorComponents {
        ColorComponents()
    }
}
