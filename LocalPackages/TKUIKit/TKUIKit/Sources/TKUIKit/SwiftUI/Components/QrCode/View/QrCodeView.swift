import SwiftUI
import UIKit

public struct QrCodeView<Overlay: View>: View {
    public let matrix: QrCodeMatrix
    public let configuration: QrCodeGeneratorConfiguration
    public let style: QrCodeStyle
    public let rippleConfiguration: QrCodeRippleConfiguration
    public let interactionMode: QrCodeInteractionMode
    private let overlay: () -> Overlay

    @Environment(\.displayScale) private var displayScale
    @Environment(\.qrCodeTapReaderEnabled) private var isTapReaderEnabled
    @Environment(\.tkResolvedTheme) private var resolvedTheme
    @State private var ripples = [QrCodeRipple]()
    @State private var tapHighlight: QrCodeTapHighlight?

    public init(
        matrix: QrCodeMatrix,
        configuration: QrCodeGeneratorConfiguration = .default,
        style: QrCodeStyle = QrCodeStyle(),
        rippleConfiguration: QrCodeRippleConfiguration = .default,
        interactionMode: QrCodeInteractionMode = .tapOnly,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.matrix = matrix
        self.configuration = configuration
        self.style = style
        self.rippleConfiguration = rippleConfiguration
        self.interactionMode = interactionMode
        self.overlay = overlay
    }

    public var body: some View {
        ZStack {
            if needsTimeline {
                TimelineView(.animation) { timeline in
                    canvas(
                        tapHighlight: tapHighlight,
                        ripples: activeRipples(at: timeline.date),
                        date: timeline.date
                    )
                }
            } else {
                canvas(
                    tapHighlight: tapHighlight,
                    ripples: [],
                    date: Date()
                )
            }

            if isTapReaderEnabled {
                TouchLocationReader(interactionMode: interactionMode) { location in
                    updateTapHighlight(with: location)
                } onTapCompleted: { location in
                    addRipple(at: location)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            overlay()
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
    }

    private func canvas(
        tapHighlight: QrCodeTapHighlight?,
        ripples: [QrCodeRipple],
        date: Date
    ) -> some View {
        Canvas(
            opaque: configuration.backgroundColor.cgColor.alpha == 1,
            rendersAsynchronously: false
        ) { context, size in
            draw(
                context: context,
                size: size,
                tapHighlight: tapHighlight,
                ripples: ripples,
                date: date
            )
        }
        .id(resolvedTheme)
    }

    private func draw(
        context: GraphicsContext,
        size: CGSize,
        tapHighlight: QrCodeTapHighlight?,
        ripples: [QrCodeRipple],
        date: Date
    ) {
        let geometry = QrCodeMatrixGeometry(
            size: size,
            matrix: matrix,
            configuration: configuration,
            screenScale: displayScale
        )
        drawBackground(
            context: context,
            size: size
        )
        drawModules(
            context: context,
            geometry: geometry,
            size: size,
            tapHighlight: tapHighlight,
            ripples: ripples,
            date: date
        )
        drawFinderPatterns(
            context: context,
            geometry: geometry,
            size: size,
            tapHighlight: tapHighlight,
            ripples: ripples,
            date: date
        )
    }

    private func drawBackground(context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(uiColor: configuration.backgroundColor))
        )
    }

    private func drawModules(
        context: GraphicsContext,
        geometry: QrCodeMatrixGeometry,
        size: CGSize,
        tapHighlight: QrCodeTapHighlight?,
        ripples: [QrCodeRipple],
        date: Date
    ) {
        let bounds = CGRect(origin: .zero, size: size)

        for y in 0 ..< matrix.height {
            for x in 0 ..< matrix.width {
                guard
                    matrix.isDark(x: x, y: y),
                    !geometry.isFinderPatternModule(x: x, y: y),
                    !geometry.isCenterCutoutModule(x: x, y: y)
                else {
                    continue
                }
                let moduleRect = geometry.moduleRect(x: x, y: y)
                let influence = dotInfluence(
                    at: CGPoint(
                        x: moduleRect.midX,
                        y: moduleRect.midY
                    ),
                    bounds: bounds,
                    geometry: geometry,
                    tapHighlight: tapHighlight,
                    ripples: ripples,
                    date: date
                )
                let dotRect = geometry.dotRect(
                    x: x,
                    y: y,
                    diameterMultiplier: 1 - rippleConfiguration.maxDotDiameterReduction * influence
                )
                var path = Path()
                path.addEllipse(in: dotRect)
                context.fill(
                    path,
                    with: .color(style.moduleColor)
                )
            }
        }
    }

    private func drawFinderPatterns(
        context: GraphicsContext,
        geometry: QrCodeMatrixGeometry,
        size: CGSize,
        tapHighlight: QrCodeTapHighlight?,
        ripples: [QrCodeRipple],
        date: Date
    ) {
        let bounds = CGRect(origin: .zero, size: size)

        for finderPattern in geometry.finderPatterns {
            let finderPatternRect = geometry.finderPatternRect(finderPattern, inset: 0)
            let influence = finderPatternInfluence(
                finderPattern,
                bounds: bounds,
                geometry: geometry,
                tapHighlight: tapHighlight,
                ripples: ripples,
                date: date
            )
            let opacity = QrCodeFinderPatternOpacityEffect.opacity(
                influence: influence,
                rippleConfiguration: rippleConfiguration
            )
            drawFinderPattern(
                context: context,
                geometry: geometry,
                finderPattern: finderPattern,
                finderPatternRect: finderPatternRect,
                darkPatternOpacity: opacity
            )
        }
    }

    private func drawFinderPattern(
        context: GraphicsContext,
        geometry: QrCodeMatrixGeometry,
        finderPattern: QrCodeFinderPattern,
        finderPatternRect: CGRect,
        darkPatternOpacity: Double
    ) {
        let darkPatternColor = style.finderPatternColor.opacity(darkPatternOpacity)

        context.fill(
            Path(
                roundedRect: finderPatternRect,
                cornerRadius: geometry.moduleSide * QrCodeViewLayout.outerFinderCornerRadius
            ),
            with: .color(darkPatternColor)
        )

        let middleFillColor = Color(uiColor: configuration.backgroundColor)
        context.fill(
            Path(
                roundedRect: geometry.finderPatternRect(finderPattern, inset: 1),
                cornerRadius: geometry.moduleSide * QrCodeViewLayout.middleFinderCornerRadius
            ),
            with: .color(middleFillColor)
        )

        context.fill(
            Path(
                roundedRect: geometry.finderPatternRect(finderPattern, inset: 2),
                cornerRadius: geometry.moduleSide * QrCodeViewLayout.innerFinderCornerRadius
            ),
            with: .color(darkPatternColor)
        )
    }

    private func finderPatternInfluence(
        _ finderPattern: QrCodeFinderPattern,
        bounds: CGRect,
        geometry: QrCodeMatrixGeometry,
        tapHighlight: QrCodeTapHighlight?,
        ripples: [QrCodeRipple],
        date: Date
    ) -> CGFloat {
        guard finderPattern.size > 0 else {
            return 0
        }

        var totalInfluence: CGFloat = 0
        var sampleCount: CGFloat = 0

        for yOffset in 0 ..< finderPattern.size {
            for xOffset in 0 ..< finderPattern.size {
                let moduleRect = geometry.moduleRect(
                    x: finderPattern.x + xOffset,
                    y: finderPattern.y + yOffset
                )
                totalInfluence += dotInfluence(
                    at: CGPoint(
                        x: moduleRect.midX,
                        y: moduleRect.midY
                    ),
                    bounds: bounds,
                    geometry: geometry,
                    tapHighlight: tapHighlight,
                    ripples: ripples,
                    date: date
                )
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else {
            return 0
        }

        return totalInfluence / sampleCount
    }

    private func dotInfluence(
        at point: CGPoint,
        bounds: CGRect,
        geometry: QrCodeMatrixGeometry,
        tapHighlight: QrCodeTapHighlight?,
        ripples: [QrCodeRipple],
        date: Date
    ) -> CGFloat {
        let tapInfluence = QrCodeTapEffect.influence(
            at: point,
            activeTapOrigin: tapHighlight?.origin,
            moduleSide: geometry.moduleSide,
            rippleConfiguration: rippleConfiguration
        ) * (tapHighlight?.progress(at: date) ?? 0)
        let rippleInfluence = QrCodeRippleEffect.combinedInfluence(
            at: point,
            ripples: ripples,
            date: date,
            bounds: bounds,
            moduleSide: geometry.moduleSide,
            rippleConfiguration: rippleConfiguration
        )
        return (tapInfluence + rippleInfluence).clamped(to: 0 ... QrCodeTapEffect.maximumInfluence)
    }

    private var needsTimeline: Bool {
        let date = Date()
        return !activeRipples(at: date).isEmpty || tapHighlight?.isAnimating(at: date) == true
    }

    private func updateTapHighlight(with location: CGPoint?) {
        let date = Date()
        if let location {
            tapHighlight = tapHighlight?.pressing(at: date, origin: location)
                ?? QrCodeTapHighlight(origin: location, date: date)
            scheduleTapHighlightResolution()
        } else {
            tapHighlight = tapHighlight?.releasing(at: date)
            scheduleTapHighlightResolution()
        }
    }

    private func scheduleTapHighlightResolution() {
        guard let transitionID = tapHighlight?.transitionID else {
            return
        }

        let remainingDuration = tapHighlight?.remainingAnimationDuration(at: Date()) ?? 0
        DispatchQueue.main.asyncAfter(deadline: .now() + remainingDuration) {
            guard tapHighlight?.transitionID == transitionID else {
                return
            }

            tapHighlight = tapHighlight?.resolved(at: Date())
        }
    }

    private func addRipple(at origin: CGPoint) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let ripple = QrCodeRipple(origin: origin)
        let activeRipples = activeRipples(at: ripple.startDate) + [ripple]
        ripples = Array(activeRipples.suffix(rippleConfiguration.maxSimultaniousRipplesCount))

        DispatchQueue.main.asyncAfter(deadline: .now() + rippleConfiguration.animationDuration) {
            ripples.removeAll { $0.id == ripple.id }
        }
    }

    private func activeRipples(at date: Date) -> [QrCodeRipple] {
        ripples.filter { ripple in
            let elapsed = date.timeIntervalSince(ripple.startDate)
            return elapsed >= 0 && elapsed < rippleConfiguration.animationDuration
        }
    }
}

public extension QrCodeView where Overlay == EmptyView {
    init(
        matrix: QrCodeMatrix,
        configuration: QrCodeGeneratorConfiguration = .default,
        style: QrCodeStyle = QrCodeStyle(),
        rippleConfiguration: QrCodeRippleConfiguration = .default,
        interactionMode: QrCodeInteractionMode = .tapOnly
    ) {
        self.init(
            matrix: matrix,
            configuration: configuration,
            style: style,
            rippleConfiguration: rippleConfiguration,
            interactionMode: interactionMode,
            overlay: {
                EmptyView()
            }
        )
    }
}
