import SwiftUI
import UIKit

@MainActor
final class TKLineChartRenderer: ObservableObject {
    struct RenderModel: Equatable {
        var mode: TKLineChartCanvasView.ChartMode
        var smoothing: CGFloat
        var style: TKLineChartCanvasView.VisualStyle
        var appearance: TKLineChartCanvasView.Appearance
        var trend: LineChartTrend
        var animatedYValues: AnimatableChartVector
        var points: [NormalizedChartPoint]

        static let empty = RenderModel(
            mode: .linear,
            smoothing: 0,
            style: .active,
            appearance: .standard,
            trend: .upOrFlat,
            animatedYValues: .zero,
            points: []
        )
    }

    @Published private(set) var renderModel: RenderModel = .empty
    @Published fileprivate var selectedIndex: Int?
    @Published fileprivate var isDragging = false

    init(chartData: TKLineChartCanvasView.ChartData? = nil) {
        if let chartData {
            setChartData(chartData)
        }
    }

    var didSelectValue: ((Int) -> Void)?
    var didDeselectValue: (() -> Void)?
    var didStartDragging: (() -> Void)?
    var didEndDragging: (() -> Void)?
    func setChartData(_ chartData: TKLineChartCanvasView.ChartData) {
        let points = LineChartPointNormalizer.normalize(chartData.coordinates)
        let areaMaskModel = LineChartAreaMaskModel(
            chartData: chartData,
            points: points
        )
        let model = RenderModel(
            mode: areaMaskModel.mode,
            smoothing: areaMaskModel.smoothing,
            style: chartData.style,
            appearance: chartData.appearance,
            trend: LineChartTrendResolver.trend(for: chartData.coordinates),
            animatedYValues: areaMaskModel.yValues,
            points: points
        )

        selectedIndex = nil
        isDragging = false

        if renderModel.animatedYValues.values.isEmpty {
            renderModel = model
        } else {
            withAnimation(Animation.easeInOut(duration: SampleConfiguration.animationDuration)) {
                renderModel = model
            }
        }
    }

    func updateSelection(at location: CGPoint, in size: CGSize) {
        guard renderModel.style.allowsSelection, !renderModel.points.isEmpty else { return }

        let index = nearestPointIndex(to: location, in: size)
        if !isDragging {
            isDragging = true
            didStartDragging?()
        }
        if selectedIndex != index {
            selectedIndex = index
            didSelectValue?(renderModel.points[index].sourceIndex)
        }
    }

    func finishDragging() {
        guard isDragging || selectedIndex != nil else { return }
        selectedIndex = nil
        isDragging = false
        didEndDragging?()
        didDeselectValue?()
    }

    fileprivate func plotRect(in size: CGSize) -> CGRect {
        let width = max(size.width, 0)
        let height = max(size.height, 0)
        return CGRect(
            x: 0,
            y: 0,
            width: width,
            height: height
        )
    }

    fileprivate func selectedPoint(in size: CGSize) -> CGPoint? {
        guard
            let selectedIndex,
            renderModel.points.indices.contains(selectedIndex)
        else {
            return nil
        }

        let plotRect = plotRect(in: size)
        let point = renderModel.points[selectedIndex].point
        let sampledY = RenderedChartPointSampler.yValue(
            at: point.x,
            yValues: renderModel.animatedYValues.values,
            mode: renderModel.mode,
            smoothing: renderModel.smoothing
        ) ?? point.y
        return CGPoint(
            x: plotRect.minX + point.x * plotRect.width,
            y: plotRect.minY + sampledY * plotRect.height
        )
    }

    private func nearestPointIndex(to location: CGPoint, in size: CGSize) -> Int {
        let plotRect = plotRect(in: size)
        guard plotRect.width > 0 else { return 0 }

        let clampedX = min(max(location.x, plotRect.minX), plotRect.maxX)
        let normalizedX = (clampedX - plotRect.minX) / plotRect.width

        let nearestPoint = renderModel.points.enumerated().min { lhs, rhs in
            abs(lhs.element.point.x - normalizedX) < abs(rhs.element.point.x - normalizedX)
        }

        return nearestPoint?.offset ?? 0
    }
}

@MainActor
struct TKLineChartContentView: View {
    @Environment(\.tkPalette) private var palette

    @ObservedObject var renderer: TKLineChartRenderer
    let selectionGuideHeight: CGFloat?
    let showsSelectionIndicator: Bool

    var body: some View {
        GeometryReader { geometry in
            let plotRect = renderer.plotRect(in: geometry.size)
            let renderModel = renderer.renderModel
            let guideHeight = ChartSelectionGuideLayout.height(
                requestedHeight: selectionGuideHeight,
                plotHeight: plotRect.height
            )
            ZStack(alignment: .topLeading) {
                ChartAreaFillView(
                    yValues: renderModel.animatedYValues,
                    mode: renderModel.mode,
                    smoothing: renderModel.smoothing,
                    fillGradient: renderModel.fillGradient(palette)
                )
                .frame(width: plotRect.width, height: plotRect.height)
                .offset(x: plotRect.minX, y: plotRect.minY)

                AnimatedChartLineShape(
                    yValues: renderModel.animatedYValues,
                    mode: renderModel.mode,
                    smoothing: renderModel.smoothing
                )
                .stroke(
                    renderModel.lineColor(palette),
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: plotRect.width, height: plotRect.height)
                .offset(x: plotRect.minX, y: plotRect.minY)

                if showsSelectionIndicator {
                    ChartSelectionIndicatorView(
                        renderer: renderer,
                        chartSize: geometry.size,
                        guideHeight: guideHeight
                    )
                }
            }
        }
        .background(Color.clear)
    }
}

struct ChartSelectionIndicatorView: View {
    @Environment(\.tkPalette) private var palette
    @ObservedObject var renderer: TKLineChartRenderer
    let chartSize: CGSize
    let guideHeight: CGFloat

    var body: some View {
        let renderModel = renderer.renderModel
        let guideHeight = max(guideHeight, 0)
        if renderModel.style.allowsSelection, let selectedPoint = renderer.selectedPoint(in: chartSize) {
            if renderModel.appearance == .trend {
                Path { path in
                    path.move(to: CGPoint(x: selectedPoint.x, y: 0))
                    path.addLine(to: CGPoint(x: selectedPoint.x, y: guideHeight))
                }
                .stroke(
                    palette.icon.primary,
                    style: StrokeStyle(
                        lineWidth: SelectionIndicatorStyle.lineWidth,
                        dash: [SelectionIndicatorStyle.dashLength]
                    )
                )

                Circle()
                    .fill(.iconPrimary.opacity(SelectionIndicatorStyle.outerCircleOpacity))
                    .frame(
                        width: SelectionIndicatorStyle.trendOuterCircleDiameter,
                        height: SelectionIndicatorStyle.trendOuterCircleDiameter
                    )
                    .offset(
                        x: selectedPoint.x - SelectionIndicatorStyle.trendOuterCircleDiameter / 2,
                        y: selectedPoint.y - SelectionIndicatorStyle.trendOuterCircleDiameter / 2
                    )

                Circle()
                    .fill(.iconPrimary)
                    .frame(
                        width: SelectionIndicatorStyle.trendInnerCircleDiameter,
                        height: SelectionIndicatorStyle.trendInnerCircleDiameter
                    )
                    .offset(
                        x: selectedPoint.x - SelectionIndicatorStyle.trendInnerCircleDiameter / 2,
                        y: selectedPoint.y - SelectionIndicatorStyle.trendInnerCircleDiameter / 2
                    )
            } else {
                Rectangle()
                    .fill(renderModel.lineColor(palette))
                    .frame(width: SelectionIndicatorStyle.lineWidth, height: guideHeight)
                    .offset(
                        x: selectedPoint.x - SelectionIndicatorStyle.lineWidth / 2,
                        y: 0
                    )

                Circle()
                    .fill(renderModel.lineColor(palette).opacity(SelectionIndicatorStyle.outerCircleOpacity))
                    .frame(
                        width: SelectionIndicatorStyle.standardOuterCircleDiameter,
                        height: SelectionIndicatorStyle.standardOuterCircleDiameter
                    )
                    .offset(
                        x: selectedPoint.x - SelectionIndicatorStyle.standardOuterCircleDiameter / 2,
                        y: selectedPoint.y - SelectionIndicatorStyle.standardOuterCircleDiameter / 2
                    )

                Circle()
                    .fill(renderModel.lineColor(palette))
                    .frame(
                        width: SelectionIndicatorStyle.standardInnerCircleDiameter,
                        height: SelectionIndicatorStyle.standardInnerCircleDiameter
                    )
                    .offset(
                        x: selectedPoint.x - SelectionIndicatorStyle.standardInnerCircleDiameter / 2,
                        y: selectedPoint.y - SelectionIndicatorStyle.standardInnerCircleDiameter / 2
                    )
            }
        }
    }
}

enum ChartSelectionGuideLayout {
    static func height(requestedHeight: CGFloat?, plotHeight: CGFloat) -> CGFloat {
        max(requestedHeight ?? plotHeight, 0)
    }
}

private struct ChartAreaFillView: View {
    var yValues: AnimatableChartVector
    let mode: TKLineChartCanvasView.ChartMode
    let smoothing: CGFloat
    let fillGradient: Gradient

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: fillGradient,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(0.24)
            )
            .mask {
                ChartAreaMaskView(
                    yValues: yValues,
                    mode: mode,
                    smoothing: smoothing
                )
            }
    }
}

private struct ChartAreaMaskView: View {
    var yValues: AnimatableChartVector
    let mode: TKLineChartCanvasView.ChartMode
    let smoothing: CGFloat

    var body: some View {
        AnimatedChartAreaShape(
            yValues: yValues,
            mode: mode,
            smoothing: smoothing
        )
        .fill(.white)
    }
}

struct ChartExtendedAreaMaskView: View {
    var yValues: AnimatableChartVector
    let mode: TKLineChartCanvasView.ChartMode
    let smoothing: CGFloat
    let chartHeight: CGFloat

    var body: some View {
        AnimatedExtendedChartAreaShape(
            yValues: yValues,
            mode: mode,
            smoothing: smoothing,
            chartHeight: chartHeight
        )
        .fill(.white)
    }
}

private enum SelectionIndicatorStyle {
    static let lineWidth: CGFloat = 1
    static let dashLength: CGFloat = 3
    static let standardOuterCircleDiameter: CGFloat = 40
    static let standardInnerCircleDiameter: CGFloat = 16
    static let trendOuterCircleDiameter: CGFloat = 24
    static let trendInnerCircleDiameter: CGFloat = 8
    static let outerCircleOpacity: CGFloat = 0.24
}

extension TKLineChartRenderer.RenderModel {
    func lineColor(_ palette: TKPalette) -> Color {
        LineChartColorResolver.color(
            style: style,
            appearance: appearance,
            trend: trend,
            palette: palette
        )
    }

    func substrateGridLineColor(_ palette: TKPalette) -> Color? {
        guard appearance == .trend else { return nil }
        return lineColor(palette)
    }

    func fillGradient(_ palette: TKPalette) -> Gradient {
        let color = lineColor(palette)
        return Gradient(
            stops: [
                Gradient.Stop(color: color, location: 0),
                Gradient.Stop(color: color.opacity(0.99), location: 0.0667),
                Gradient.Stop(color: color.opacity(0.96), location: 0.1333),
                Gradient.Stop(color: color.opacity(0.92), location: 0.2),
                Gradient.Stop(color: color.opacity(0.85), location: 0.2667),
                Gradient.Stop(color: color.opacity(0.77), location: 0.3333),
                Gradient.Stop(color: color.opacity(0.67), location: 0.4),
                Gradient.Stop(color: color.opacity(0.56), location: 0.4667),
                Gradient.Stop(color: color.opacity(0.44), location: 0.5333),
                Gradient.Stop(color: color.opacity(0.33), location: 0.6),
                Gradient.Stop(color: color.opacity(0.23), location: 0.6667),
                Gradient.Stop(color: color.opacity(0.15), location: 0.7333),
                Gradient.Stop(color: color.opacity(0.08), location: 0.8),
                Gradient.Stop(color: color.opacity(0.04), location: 0.8667),
                Gradient.Stop(color: color.opacity(0.01), location: 0.9333),
                Gradient.Stop(color: color.opacity(0), location: 1),
            ]
        )
    }
}

private enum SampleConfiguration {
    static let sampleCount = 96
    static let animationDuration = 0.15
}

struct LineChartAreaMaskModel {
    let yValues: AnimatableChartVector
    let mode: TKLineChartCanvasView.ChartMode
    let smoothing: CGFloat

    init(
        chartData: TKLineChartCanvasView.ChartData,
        points: [NormalizedChartPoint]
    ) {
        mode = chartData.mode
        smoothing = chartData.smoothing.resolvedTension
        yValues = AnimatableChartVector(
            values: LineChartPointSampler.sample(
                points: points,
                mode: chartData.mode,
                sampleCount: SampleConfiguration.sampleCount
            )
        )
    }
}

struct NormalizedChartPoint: Equatable {
    let sourceIndex: Int
    let point: CGPoint
}

enum LineChartTrend: Equatable {
    case down
    case upOrFlat
}

enum LineChartTrendResolver {
    static func trend(for coordinates: [Coordinate]) -> LineChartTrend {
        guard
            let firstSample = coordinates.min(by: { $0.x < $1.x }),
            let lastSample = coordinates.max(by: { $0.x < $1.x })
        else {
            return .upOrFlat
        }

        return firstSample.y > lastSample.y ? .down : .upOrFlat
    }
}

enum LineChartColorResolver {
    static func color(
        style: TKLineChartCanvasView.VisualStyle,
        appearance: TKLineChartCanvasView.Appearance,
        trend: LineChartTrend,
        palette: TKPalette
    ) -> Color {
        switch style {
        case .active:
            switch appearance {
            case .standard:
                return palette.accent.blue
            case .trend:
                switch trend {
                case .down:
                    return palette.accent.red
                case .upOrFlat:
                    return palette.accent.green
                }
            }
        case .skeleton:
            return palette.background.contentTint
        }
    }
}

enum LineChartPointNormalizer {
    static func normalize(_ coordinates: [Coordinate]) -> [NormalizedChartPoint] {
        guard !coordinates.isEmpty else { return [] }

        let xValues = coordinates.map(\.x)
        let yValues = coordinates.map(\.y)

        let minX = xValues.min() ?? 0
        let maxX = xValues.max() ?? 0
        let xRange = maxX - minX

        let minY = yValues.min() ?? 0
        let maxY = yValues.max() ?? 0
        let yRange = maxY - minY

        let lastIndex = max(coordinates.count - 1, 1)

        return coordinates.enumerated().map { index, coordinate in
            let normalizedX: CGFloat
            if xRange > 0 {
                normalizedX = CGFloat((coordinate.x - minX) / xRange)
            } else if coordinates.count == 1 {
                normalizedX = 0.5
            } else {
                normalizedX = CGFloat(index) / CGFloat(lastIndex)
            }

            let normalizedY: CGFloat
            if yRange > 0 {
                normalizedY = CGFloat((maxY - coordinate.y) / yRange)
            } else {
                normalizedY = 0.5
            }

            return NormalizedChartPoint(
                sourceIndex: index,
                point: CGPoint(
                    x: min(max(normalizedX, 0), 1),
                    y: min(max(normalizedY, 0), 1)
                )
            )
        }
        .sorted { lhs, rhs in
            let deltaX = lhs.point.x - rhs.point.x
            if abs(deltaX) > .ulpOfOne {
                return deltaX < 0
            }
            return lhs.sourceIndex < rhs.sourceIndex
        }
    }
}

enum LineChartPointSampler {
    static func sample(
        points: [NormalizedChartPoint],
        mode: TKLineChartCanvasView.ChartMode,
        sampleCount: Int
    ) -> [CGFloat] {
        guard !points.isEmpty else { return [] }
        let normalizedPoints = points.map(\.point)

        if normalizedPoints.count == 1 {
            return Array(repeating: normalizedPoints[0].y, count: sampleCount)
        }

        return (0 ..< sampleCount).map { index in
            let x = CGFloat(index) / CGFloat(max(sampleCount - 1, 1))
            return yValue(at: x, points: normalizedPoints, mode: mode)
        }
    }

    private static func yValue(
        at x: CGFloat,
        points: [CGPoint],
        mode: TKLineChartCanvasView.ChartMode
    ) -> CGFloat {
        guard let first = points.first, let last = points.last else {
            return 0
        }

        if x <= first.x { return first.y }
        if x >= last.x { return last.y }

        for index in 1 ..< points.count {
            let previous = points[index - 1]
            let current = points[index]
            if x <= current.x {
                switch mode {
                case .linear:
                    let denominator = max(current.x - previous.x, .ulpOfOne)
                    let progress = (x - previous.x) / denominator
                    return previous.y + ((current.y - previous.y) * progress)
                case .stepped:
                    return previous.y
                }
            }
        }

        return last.y
    }
}

enum RenderedChartPointSampler {
    static func yValue(
        at normalizedX: CGFloat,
        yValues: [CGFloat],
        mode: TKLineChartCanvasView.ChartMode,
        smoothing: CGFloat
    ) -> CGFloat? {
        guard !yValues.isEmpty else { return nil }

        if yValues.count == 1 {
            return clamp(yValues[0])
        }

        let clampedX = min(max(normalizedX, 0), 1)
        let points = samplePoints(for: yValues)
        guard
            let first = points.first,
            let last = points.last
        else {
            return nil
        }

        if clampedX <= first.x { return first.y }
        if clampedX >= last.x { return last.y }

        let segmentWidth = 1 / CGFloat(max(points.count - 1, 1))
        let snappedIndex = Int((clampedX / max(segmentWidth, .ulpOfOne)).rounded())
        if points.indices.contains(snappedIndex) {
            let snappedX = CGFloat(snappedIndex) * segmentWidth
            if abs(clampedX - snappedX) <= segmentWidth * 0.0001 {
                return points[snappedIndex].y
            }
        }

        let leftIndex = min(
            max(Int(floor(clampedX / max(segmentWidth, .ulpOfOne))), 0),
            points.count - 2
        )

        switch mode {
        case .stepped:
            return points[leftIndex].y
        case .linear:
            let start = points[leftIndex]
            let end = points[leftIndex + 1]
            let clampedSmoothing = min(max(smoothing, 0), 1)

            guard clampedSmoothing > 0.001, points.count > 2 else {
                let progress = (clampedX - start.x) / max(end.x - start.x, .ulpOfOne)
                return start.y + ((end.y - start.y) * progress)
            }

            let (controlPoint1, controlPoint2) = controlPoints(
                forSegmentAt: leftIndex,
                points: points,
                smoothing: clampedSmoothing
            )
            return cubicBezierY(
                at: clampedX,
                start: start,
                controlPoint1: controlPoint1,
                controlPoint2: controlPoint2,
                end: end
            )
        }
    }

    private static func samplePoints(for yValues: [CGFloat]) -> [CGPoint] {
        guard !yValues.isEmpty else { return [] }

        if yValues.count == 1 {
            return [CGPoint(x: 0.5, y: clamp(yValues[0]))]
        }

        let segmentWidth = 1 / CGFloat(max(yValues.count - 1, 1))
        return yValues.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * segmentWidth,
                y: clamp(value)
            )
        }
    }

    private static func controlPoints(
        forSegmentAt index: Int,
        points: [CGPoint],
        smoothing: CGFloat
    ) -> (CGPoint, CGPoint) {
        let previous = index > 0 ? points[index - 1] : points[index]
        let current = points[index]
        let next = points[index + 1]
        let nextNext = index + 2 < points.count ? points[index + 2] : next
        let controlPointFactor = smoothing / 6

        let controlPoint1 = CGPoint(
            x: current.x + ((next.x - previous.x) * controlPointFactor),
            y: current.y + ((next.y - previous.y) * controlPointFactor)
        )
        let controlPoint2 = CGPoint(
            x: next.x - ((nextNext.x - current.x) * controlPointFactor),
            y: next.y - ((nextNext.y - current.y) * controlPointFactor)
        )

        return (controlPoint1, controlPoint2)
    }

    private static func cubicBezierY(
        at x: CGFloat,
        start: CGPoint,
        controlPoint1: CGPoint,
        controlPoint2: CGPoint,
        end: CGPoint
    ) -> CGFloat {
        var lowerBound: CGFloat = 0
        var upperBound: CGFloat = 1

        // The x component is monotonic for the generated control points, so binary search is stable here.
        for _ in 0 ..< 16 {
            let parameter = (lowerBound + upperBound) / 2
            let point = cubicBezierPoint(
                at: parameter,
                start: start,
                controlPoint1: controlPoint1,
                controlPoint2: controlPoint2,
                end: end
            )

            if point.x < x {
                lowerBound = parameter
            } else {
                upperBound = parameter
            }
        }

        let parameter = (lowerBound + upperBound) / 2
        return cubicBezierPoint(
            at: parameter,
            start: start,
            controlPoint1: controlPoint1,
            controlPoint2: controlPoint2,
            end: end
        ).y
    }

    private static func cubicBezierPoint(
        at parameter: CGFloat,
        start: CGPoint,
        controlPoint1: CGPoint,
        controlPoint2: CGPoint,
        end: CGPoint
    ) -> CGPoint {
        let inverse = 1 - parameter
        let inverseSquared = inverse * inverse
        let inverseCubed = inverseSquared * inverse
        let parameterSquared = parameter * parameter
        let parameterCubed = parameterSquared * parameter

        let x = (inverseCubed * start.x)
            + (3 * inverseSquared * parameter * controlPoint1.x)
            + (3 * inverse * parameterSquared * controlPoint2.x)
            + (parameterCubed * end.x)
        let y = (inverseCubed * start.y)
            + (3 * inverseSquared * parameter * controlPoint1.y)
            + (3 * inverse * parameterSquared * controlPoint2.y)
            + (parameterCubed * end.y)

        return CGPoint(x: x, y: y)
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

struct AnimatableChartVector: VectorArithmetic {
    var values: [CGFloat]

    static let zero = AnimatableChartVector(values: [])

    static func + (lhs: AnimatableChartVector, rhs: AnimatableChartVector) -> AnimatableChartVector {
        let maxCount = max(lhs.values.count, rhs.values.count)
        return AnimatableChartVector(
            values: (0 ..< maxCount).map { index in
                lhs.value(at: index) + rhs.value(at: index)
            }
        )
    }

    static func - (lhs: AnimatableChartVector, rhs: AnimatableChartVector) -> AnimatableChartVector {
        let maxCount = max(lhs.values.count, rhs.values.count)
        return AnimatableChartVector(
            values: (0 ..< maxCount).map { index in
                lhs.value(at: index) - rhs.value(at: index)
            }
        )
    }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * CGFloat(rhs) }
    }

    var magnitudeSquared: Double {
        values.reduce(0) { partialResult, value in
            partialResult + Double(value * value)
        }
    }

    private func value(at index: Int) -> CGFloat {
        if values.indices.contains(index) {
            return values[index]
        }
        return values.last ?? 0
    }
}

private struct AnimatedChartLineShape: Shape {
    var yValues: AnimatableChartVector
    let mode: TKLineChartCanvasView.ChartMode
    let smoothing: CGFloat

    var animatableData: AnimatableChartVector {
        get { yValues }
        set { yValues = newValue }
    }

    func path(in rect: CGRect) -> Path {
        ChartPathBuilder.linePath(
            in: rect,
            yValues: yValues.values,
            mode: mode,
            smoothing: smoothing
        )
    }
}

private struct AnimatedChartAreaShape: Shape {
    var yValues: AnimatableChartVector
    let mode: TKLineChartCanvasView.ChartMode
    let smoothing: CGFloat

    var animatableData: AnimatableChartVector {
        get { yValues }
        set { yValues = newValue }
    }

    func path(in rect: CGRect) -> Path {
        ChartPathBuilder.areaPath(
            in: rect,
            yValues: yValues.values,
            mode: mode,
            smoothing: smoothing
        )
    }
}

private struct AnimatedExtendedChartAreaShape: Shape {
    var yValues: AnimatableChartVector
    let mode: TKLineChartCanvasView.ChartMode
    let smoothing: CGFloat
    let chartHeight: CGFloat

    var animatableData: AnimatableChartVector {
        get { yValues }
        set { yValues = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let layout = ChartExtendedAreaMaskLayout.layout(
            in: rect,
            chartHeight: chartHeight
        )
        return ChartPathBuilder.areaPath(
            in: layout.chartRect,
            yValues: yValues.values,
            mode: mode,
            smoothing: smoothing,
            closingY: layout.outputRect.maxY
        )
    }
}

struct ChartExtendedAreaMaskLayout: Equatable {
    let chartRect: CGRect
    let outputRect: CGRect

    static func layout(in rect: CGRect, chartHeight: CGFloat) -> ChartExtendedAreaMaskLayout {
        let outputRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: max(rect.width, 0),
            height: max(rect.height, 0)
        )
        let chartRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: max(rect.width, 0),
            height: max(chartHeight, 0)
        )
        return ChartExtendedAreaMaskLayout(
            chartRect: chartRect,
            outputRect: outputRect
        )
    }
}

private enum ChartPathBuilder {
    static func linePath(
        in rect: CGRect,
        yValues: [CGFloat],
        mode: TKLineChartCanvasView.ChartMode,
        smoothing: CGFloat
    ) -> Path {
        let points = buildPoints(in: rect, yValues: yValues)
        guard let first = points.first else { return Path() }

        var path = Path()
        path.move(to: first)

        switch mode {
        case .stepped:
            addStepSegments(points: points, to: &path)
        case .linear:
            addLinearSegments(points: points, smoothing: smoothing, to: &path)
        }

        return path
    }

    static func areaPath(
        in rect: CGRect,
        yValues: [CGFloat],
        mode: TKLineChartCanvasView.ChartMode,
        smoothing: CGFloat,
        closingY: CGFloat? = nil
    ) -> Path {
        let points = buildPoints(in: rect, yValues: yValues)
        guard let first = points.first, let last = points.last else { return Path() }

        let closingY = closingY ?? rect.maxY
        var path = linePath(in: rect, yValues: yValues, mode: mode, smoothing: smoothing)
        path.addLine(to: CGPoint(x: last.x, y: closingY))
        path.addLine(to: CGPoint(x: first.x, y: closingY))
        path.closeSubpath()
        return path
    }

    private static func buildPoints(in rect: CGRect, yValues: [CGFloat]) -> [CGPoint] {
        guard !yValues.isEmpty else { return [] }

        if yValues.count == 1 {
            return [
                CGPoint(
                    x: rect.midX,
                    y: rect.minY + min(max(yValues[0], 0), 1) * rect.height
                ),
            ]
        }

        let stepX = rect.width / CGFloat(max(yValues.count - 1, 1))
        return yValues.enumerated().map { index, value in
            CGPoint(
                x: rect.minX + CGFloat(index) * stepX,
                y: rect.minY + min(max(value, 0), 1) * rect.height
            )
        }
    }

    private static func addStepSegments(points: [CGPoint], to path: inout Path) {
        guard let first = points.first else { return }
        var previous = first
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x, y: previous.y))
            path.addLine(to: point)
            previous = point
        }
    }

    private static func addLinearSegments(points: [CGPoint], smoothing: CGFloat, to path: inout Path) {
        guard points.count > 1 else { return }
        let clampedSmoothing = min(max(smoothing, 0), 1)
        guard clampedSmoothing > 0.001, points.count > 2 else {
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            return
        }

        let controlPointFactor = clampedSmoothing / 6

        for index in 0 ..< (points.count - 1) {
            let previous = index > 0 ? points[index - 1] : points[index]
            let current = points[index]
            let next = points[index + 1]
            let nextNext = index + 2 < points.count ? points[index + 2] : next

            let controlPoint1 = CGPoint(
                x: current.x + ((next.x - previous.x) * controlPointFactor),
                y: current.y + ((next.y - previous.y) * controlPointFactor)
            )
            let controlPoint2 = CGPoint(
                x: next.x - ((nextNext.x - current.x) * controlPointFactor),
                y: next.y - ((nextNext.y - current.y) * controlPointFactor)
            )

            path.addCurve(
                to: next,
                control1: controlPoint1,
                control2: controlPoint2
            )
        }
    }
}
