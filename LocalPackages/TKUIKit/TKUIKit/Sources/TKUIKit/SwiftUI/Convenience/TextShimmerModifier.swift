import SwiftUI

public extension View {
    func tkTextShimmer(
        isActive: Bool,
        dimmingInto background: TKColor? = nil,
        appearsAfter delay: TimeInterval = 0,
        scope: String? = nil
    ) -> some View {
        modifier(
            TextShimmerModifier(
                isActive: isActive,
                background: background,
                delay: delay,
                scope: scope
            )
        )
    }
}

private struct TextShimmerModifier: ViewModifier {
    let isActive: Bool
    let background: TKColor?
    let delay: TimeInterval
    let scope: String?

    private struct Appearance: Equatable {
        let scope: String?
        let since: Date
    }

    private struct Trigger: Equatable {
        let isActive: Bool
        let scope: String?
    }

    @State private var appearance: Appearance?

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    if appearance != nil {
                        band(masking: content)
                    }
                }
                .animation(TextShimmerTiming.fadeAnimation, value: appearance != nil)
            }
            .task(id: Trigger(isActive: isActive, scope: scope)) {
                await follow()
            }
            .onDisappear {
                appearance = nil
            }
    }

    private func band(masking content: Content) -> some View {
        ZStack {
            if let background {
                background.opacity(Layout.dimOpacity)
            }
            TextShimmerBand()
        }
        .mask(content)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    @MainActor
    private func follow() async {
        if let appearance, appearance.scope != scope {
            self.appearance = nil
        }
        guard isActive else {
            return await hide()
        }
        guard appearance == nil, await sleepCompleted(delay) else {
            return
        }
        appearance = Appearance(scope: scope, since: Date())
    }

    @MainActor
    private func hide() async {
        guard let appearance else {
            return
        }
        let owed = TextShimmerTiming.pass - Date().timeIntervalSince(appearance.since)
        if owed > 0 {
            guard await sleepCompleted(owed) else {
                return
            }
        }
        self.appearance = nil
    }

    private enum Layout {
        static let dimOpacity: Double = 0.6
    }
}

private struct TextShimmerBand: View {
    @Environment(\.tkPalette) private var palette
    @State private var phase: CGFloat = 0

    var body: some View {
        LinearGradient(
            stops: Layout.bellStops(in: Layout.highlight.resolve(palette)),
            startPoint: .leading,
            endPoint: .trailing
        )
        .modifier(Sweep(phase: phase))
        .task {
            await sweepForever()
        }
    }

    private func sweepForever() async {
        while !Task.isCancelled {
            withAnimation(TextShimmerTiming.passAnimation) {
                phase = 1
            }
            guard await sleepCompleted(TextShimmerTiming.pass) else { return }
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { phase = 0 }
            guard await sleepCompleted(TextShimmerTiming.pause) else { return }
        }
    }

    private struct Sweep: GeometryEffect {
        var phase: CGFloat

        var animatableData: CGFloat {
            get { phase }
            set { phase = newValue }
        }

        func effectValue(size: CGSize) -> ProjectionTransform {
            let width = max(size.width, Layout.minimumWidth)
            let bandWidth = width * Layout.bandWidthFactor
            let squeeze = CGAffineTransform(scaleX: Layout.bandWidthFactor, y: 1)
            let skew = CGAffineTransform(
                a: 1,
                b: 0,
                c: -tan(Layout.skewAngle * .pi / 180),
                d: 1,
                tx: 0,
                ty: 0
            )
            let travel = CGAffineTransform(
                translationX: -bandWidth + (width + bandWidth) * phase,
                y: 0
            )
            return ProjectionTransform(
                squeeze.concatenating(skew).concatenating(travel)
            )
        }
    }

    private enum Layout {
        static let bandWidthFactor: CGFloat = 0.7
        static let skewAngle: CGFloat = 10
        static let minimumWidth: CGFloat = 1

        static let highlight = TKColor.perTheme(
            light: Color(uiColor: UIColor(hex: "1F5FBF")),
            dark: Color(uiColor: UIColor(hex: "C2DAFF")),
            deepBlue: Color(uiColor: UIColor(hex: "C2DAFF"))
        )

        static func bellStops(in color: Color) -> [Gradient.Stop] {
            let alphas: [Double] = [0, 0.08, 0.38, 0.98, 0.38, 0.08, 0]
            return alphas.enumerated().map { index, alpha in
                Gradient.Stop(
                    color: color.opacity(alpha),
                    location: CGFloat(index) / CGFloat(alphas.count - 1)
                )
            }
        }
    }
}

private enum TextShimmerTiming {
    static let pass: TimeInterval = 1.4
    static let pause: TimeInterval = 0.2
    static let passAnimation: Animation = .timingCurve(0.65, 0, 0.35, 1, duration: pass)
    static let fadeAnimation: Animation = .easeOut(duration: 0.25)
}

private func sleepCompleted(_ interval: TimeInterval) async -> Bool {
    do {
        try await Task.sleep(nanoseconds: UInt64(max(0, interval) * 1_000_000_000))
    } catch {
        return false
    }
    return !Task.isCancelled
}
