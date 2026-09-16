import SwiftUI

/// The glow behind the start screen is the brand mark's silhouette blown far past the viewport,
/// filled with a gradient and blurred; the path, the gradient and the blur radius are the design's.
///
/// Where it departs from the design tree, and why. The design stacks two identical copies; drawn
/// that way the glow reached far further down the screen and out to the sides than the mockup does.
/// One copy is closer but still too slow to fall off, and neither a tighter radius nor splitting the
/// blur into two passes moves the falloff — the platform blur turns out to be a fair Gaussian, so
/// the difference is in how Figma composes the two layers, not in the blur.
///
/// So the layer is masked by a second copy of itself, which multiplies the coverage by itself. That
/// leaves the saturated middle alone and pulls the thin tails down towards the mockup.
///
/// Both the squaring and the radius are fitted against the design's own render, not derived from it:
/// sweeping radius against exponent, the error bottoms out at 74 and a square, and the best the grid
/// offers anywhere — 68 and a 2.25 power — is no better. The design states 81.25, which measures
/// twice as far off. If the artwork changes, measure again rather than trusting these numbers.
struct OnboardingRootBackground: View {
    var body: some View {
        GeometryReader { proxy in
            glow(scale: proxy.size.width / Layout.designWidth)
        }
        .ignoresSafeArea()
    }
}

private extension OnboardingRootBackground {
    func glow(scale: CGFloat) -> some View {
        blurredSilhouette(scale: scale)
            .mask { blurredSilhouette(scale: scale) }
            .offset(
                x: Layout.origin.x * scale,
                y: Layout.origin.y * scale
            )
    }

    func blurredSilhouette(scale: CGFloat) -> some View {
        SilhouetteShape()
            .fill(
                LinearGradient(
                    stops: Layout.stops,
                    startPoint: Layout.gradientStart,
                    endPoint: Layout.gradientEnd
                )
            )
            .frame(
                width: Layout.size.width * scale,
                height: Layout.size.height * scale
            )
            .blur(radius: Layout.blurRadius * scale)
    }

    /// Points come from the design as fractions of the silhouette's own box, so the shape keeps its
    /// proportions whatever the screen width scales it to.
    struct SilhouetteShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            for (index, point) in Layout.silhouette.enumerated() {
                let scaled = CGPoint(
                    x: rect.minX + point.x * rect.width,
                    y: rect.minY + point.y * rect.height
                )
                if index == 0 {
                    path.move(to: scaled)
                } else {
                    path.addLine(to: scaled)
                }
            }
            path.closeSubpath()
            return path
        }
    }

    enum Layout {
        static let designWidth: CGFloat = 390
        static let size = CGSize(width: 691.694, height: 684.306)
        static let origin = CGPoint(x: -150.694, y: -219)
        static let blurRadius: CGFloat = 74

        static let silhouette: [CGPoint] = [
            CGPoint(x: 1, y: 0.22217),
            CGPoint(x: 0.99926, y: 0.2225),
            CGPoint(x: 0.49973, y: 1),
            CGPoint(x: 0, y: 0.22217),
            CGPoint(x: 0.49973, y: 0.44439),
            CGPoint(x: 0.49995, y: 0.4443),
            CGPoint(x: 0, y: 0.22217),
            CGPoint(x: 0.49999, y: 0),
            CGPoint(x: 1, y: 0.22217),
        ]

        static let gradientStart = UnitPoint(x: 0.5, y: -0.01989)
        static let gradientEnd = UnitPoint(x: 0.99292, y: 0.68448)

        static let stops: [Gradient.Stop] = [
            .init(color: Color(hex: 0x3D9FFF), location: 0),
            .init(color: Color(hex: 0x3899FF), location: 0.0714286),
            .init(color: Color(hex: 0x3493FF), location: 0.142857),
            .init(color: Color(hex: 0x2E8CFF), location: 0.214286),
            .init(color: Color(hex: 0x2986FF), location: 0.285714),
            .init(color: Color(hex: 0x247FFF), location: 0.357143),
            .init(color: Color(hex: 0x1F79FF), location: 0.428571),
            .init(color: Color(hex: 0x1A73FF), location: 0.5),
            .init(color: Color(hex: 0x156CFF), location: 0.571429),
            .init(color: Color(hex: 0x1066FF), location: 0.642857),
            .init(color: Color(hex: 0x0B5FFF), location: 0.714286),
            .init(color: Color(hex: 0x0659FF), location: 0.785714),
            .init(color: Color(hex: 0x0442C5), location: 0.857143),
            .init(color: Color(hex: 0x032E93), location: 0.928571),
            .init(color: Color(hex: 0x011759), location: 1),
        ]
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
