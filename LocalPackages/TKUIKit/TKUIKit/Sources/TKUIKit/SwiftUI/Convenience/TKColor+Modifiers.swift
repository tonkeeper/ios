import SwiftUI

/// Themed counterparts of the native style modifiers; each resolves the token
/// against `tkPalette` at its own node, so callers need no environment access.
/// When the deployment target reaches iOS 17, replace these overloads with
/// `TKColor: ShapeStyle` (`resolve(in:)`) — call sites stay unchanged.
public extension View {
    func foregroundStyle(_ color: TKColor) -> some View {
        modifier(TKForegroundStyleModifier(color: color))
    }

    func background(
        _ color: TKColor,
        ignoresSafeAreaEdges edges: Edge.Set = .all
    ) -> some View {
        modifier(TKBackgroundModifier(color: color, edges: edges))
    }

    func tint(_ color: TKColor) -> some View {
        modifier(TKTintModifier(color: color))
    }

    func shadow(
        color: TKColor,
        radius: CGFloat,
        x: CGFloat = 0,
        y: CGFloat = 0
    ) -> some View {
        modifier(TKShadowModifier(color: color, radius: radius, x: x, y: y))
    }

    func tkScrim(_ color: TKColor, edge: Edge) -> some View {
        modifier(TKScrimModifier(color: color, edge: edge))
    }
}

public extension Text {
    /// Text's own iOS 17 `foregroundStyle` outranks the View overload in
    /// resolution even below the deployment target; this concrete overload
    /// restores the themed spelling. Note it erases to `some View` — for
    /// results that must stay `Text` (concatenation, prompts) use
    /// `foregroundColor(palette...)` with the environment.
    func foregroundStyle(_ color: TKColor) -> some View {
        modifier(TKForegroundStyleModifier(color: color))
    }
}

public extension Shape {
    func fill(_ color: TKColor, style: FillStyle = FillStyle()) -> some View {
        TKFilledShape(shape: self, color: color, style: style)
    }

    func stroke(_ color: TKColor, style: StrokeStyle = StrokeStyle()) -> some View {
        TKStrokedShape(shape: self, color: color, style: style)
    }

    func stroke(_ color: TKColor, lineWidth: CGFloat = 1) -> some View {
        stroke(color, style: StrokeStyle(lineWidth: lineWidth))
    }
}

public extension InsettableShape {
    func strokeBorder(_ color: TKColor, style: StrokeStyle, antialiased: Bool = true) -> some View {
        TKStrokeBorderShape(shape: self, color: color, style: style, antialiased: antialiased)
    }

    func strokeBorder(_ color: TKColor, lineWidth: CGFloat = 1, antialiased: Bool = true) -> some View {
        strokeBorder(color, style: StrokeStyle(lineWidth: lineWidth), antialiased: antialiased)
    }
}

private struct TKForegroundStyleModifier: ViewModifier {
    @Environment(\.tkPalette) private var palette

    let color: TKColor

    func body(content: Content) -> some View {
        content.foregroundStyle(color.resolve(palette))
    }
}

private struct TKBackgroundModifier: ViewModifier {
    @Environment(\.tkPalette) private var palette

    let color: TKColor
    let edges: Edge.Set

    func body(content: Content) -> some View {
        content.background(color.resolve(palette), ignoresSafeAreaEdges: edges)
    }
}

private struct TKTintModifier: ViewModifier {
    @Environment(\.tkPalette) private var palette

    let color: TKColor

    func body(content: Content) -> some View {
        content.tint(color.resolve(palette))
    }
}

private struct TKShadowModifier: ViewModifier {
    @Environment(\.tkPalette) private var palette

    let color: TKColor
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content.shadow(color: color.resolve(palette), radius: radius, x: x, y: y)
    }
}

private struct TKScrimModifier: ViewModifier {
    @Environment(\.tkPalette) private var palette

    let color: TKColor
    let edge: Edge

    func body(content: Content) -> some View {
        content.background(
            LinearGradient(
                stops: Self.opacityStops.map { stop in
                    Gradient.Stop(color: color.resolve(palette).opacity(stop.opacity), location: stop.location)
                },
                startPoint: edge.gradientStartPoint,
                endPoint: edge.gradientEndPoint
            )
        )
    }

    private static let opacityStops: [(location: CGFloat, opacity: Double)] = [
        (0, 1),
        (0.0667, 0.99),
        (0.1333, 0.96),
        (0.2, 0.92),
        (0.2667, 0.85),
        (0.3333, 0.77),
        (0.4, 0.67),
        (0.4667, 0.56),
        (0.5333, 0.44),
        (0.6, 0.33),
        (0.6667, 0.23),
        (0.7333, 0.15),
        (0.8, 0.08),
        (0.8667, 0.04),
        (0.9333, 0.01),
        (1, 0),
    ]
}

private struct TKFilledShape<S: Shape>: View {
    @Environment(\.tkPalette) private var palette

    let shape: S
    let color: TKColor
    let style: FillStyle

    var body: some View {
        shape.fill(color.resolve(palette), style: style)
    }
}

private struct TKStrokedShape<S: Shape>: View {
    @Environment(\.tkPalette) private var palette

    let shape: S
    let color: TKColor
    let style: StrokeStyle

    var body: some View {
        shape.stroke(color.resolve(palette), style: style)
    }
}

private struct TKStrokeBorderShape<S: InsettableShape>: View {
    @Environment(\.tkPalette) private var palette

    let shape: S
    let color: TKColor
    let style: StrokeStyle
    let antialiased: Bool

    var body: some View {
        shape.strokeBorder(color.resolve(palette), style: style, antialiased: antialiased)
    }
}

private extension Edge {
    var gradientStartPoint: UnitPoint {
        switch self {
        case .top:
            .top
        case .bottom:
            .bottom
        case .leading:
            .leading
        case .trailing:
            .trailing
        }
    }

    var gradientEndPoint: UnitPoint {
        switch self {
        case .top:
            .bottom
        case .bottom:
            .top
        case .leading:
            .trailing
        case .trailing:
            .leading
        }
    }
}
