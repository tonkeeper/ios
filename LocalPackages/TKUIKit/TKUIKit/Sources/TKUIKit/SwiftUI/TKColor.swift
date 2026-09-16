import SwiftUI

/// A palette color reference that is safe to store in configs built outside
/// the SwiftUI environment (view models, mappers); resolve against `tkPalette`
/// where it is rendered.
public struct TKColor: Hashable, Sendable {
    enum Base: Hashable, Sendable {
        case token(TKColorToken)
        case fixed(Color)
        case perTheme(light: Color, dark: Color, deepBlue: Color)
    }

    var base: Base
    var opacityValue: Double

    init(base: Base, opacityValue: Double = 1) {
        self.base = base
        self.opacityValue = opacityValue
    }

    static func token(_ token: TKColorToken) -> TKColor {
        TKColor(base: .token(token))
    }

    public static func fixed(_ color: Color) -> TKColor {
        TKColor(base: .fixed(color))
    }

    /// For colors outside the shared palette that still diverge per scheme.
    public static func perTheme(light: Color, dark: Color, deepBlue: Color) -> TKColor {
        TKColor(base: .perTheme(light: light, dark: dark, deepBlue: deepBlue))
    }

    public static let clear = TKColor(base: .fixed(.clear))

    public func opacity(_ value: Double) -> TKColor {
        TKColor(base: base, opacityValue: opacityValue * value)
    }

    public func resolve(_ palette: TKPalette) -> Color {
        let color: Color = switch base {
        case let .token(token):
            palette[token]
        case let .fixed(color):
            color
        case let .perTheme(light, dark, deepBlue):
            switch palette.resolvedTheme {
            case .light:
                light
            case .dark:
                dark
            case .deepBlue:
                deepBlue
            }
        }
        guard opacityValue != 1 else { return color }
        return color.opacity(opacityValue)
    }
}

extension TKColor: View {
    public var body: some View {
        TKColorView(color: self)
    }
}

private struct TKColorView: View {
    @Environment(\.tkPalette) private var palette

    let color: TKColor

    var body: some View {
        color.resolve(palette)
    }
}
