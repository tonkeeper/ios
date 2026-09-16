import SwiftUI
import UIKit

public struct ChartPreviews: View {
    @Environment(\.tkPalette) private var palette
    @State private var shimmering = false

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                Toggle(isOn: $shimmering) {
                    Text("shimmering")
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                }
                .padding(.horizontal, 16)

                previewSection(
                    title: "Component",
                    subtitle: "Chart with price overlays"
                ) {
                    ChartView(
                        config: shimmering ? .componentSkeleton : .componentInteractive
                    )
                }

                previewSection(
                    title: "Error State",
                    subtitle: "Chart data failed to load"
                ) {
                    ChartErrorContentView(
                        title: "No price data is available."
                    )
                    .frame(height: ChartView.height(showsBottomButtons: true))
                }

                previewSection(
                    title: "Line Only",
                    subtitle: "Compact chart for widget-like placements"
                ) {
                    VStack(spacing: 12) {
                        LineChartPreviewView(chartData: .linear)
                            .frame(height: Layout.lineChartHeight)

                        LineChartPreviewView(chartData: .stepped)
                            .frame(height: Layout.lineChartHeight)
                    }
                }
            }
            .padding(.vertical, Layout.contentVerticalPadding)
        }
        .tkImmediateButtonPresses()
        .background(
            palette.background.page
                .ignoresSafeArea()
        )
    }
}

private extension ChartPreviews {
    enum Layout {
        static let contentVerticalPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
        static let cardSpacing: CGFloat = 12
        static let cardCornerRadius: CGFloat = 20
        static let cardVerticalPadding: CGFloat = 16
        static let textSpacing: CGFloat = 4
        static let lineChartHeight: CGFloat = 120
    }

    func previewSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            VStack(alignment: .leading, spacing: Layout.textSpacing) {
                Text(title)
                    .textStyle(.h3)
                    .foregroundStyle(.textPrimary)

                Text(subtitle)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
            }

            content()
                .padding(.vertical, Layout.cardVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(
                        cornerRadius: Layout.cardCornerRadius,
                        style: .continuous
                    )
                    .fill(.backgroundPage)
                )
        }
    }
}

private struct LineChartPreviewView: View {
    let chartData: TKLineChartCanvasView.ChartData

    var body: some View {
        TKLineChartCanvasView(chartData: chartData)
    }
}

private struct PreviewCoordinate: Coordinate {
    let x: Double
    let y: Double
}

private extension ChartView.Config {
    static let componentInteractive = ChartView.Config(
        header: .content(
            .init(
                price: "$ 1.846",
                diff: .init(
                    diff: "+ 7.32 %",
                    priceDiff: "+ $ 0.41",
                    direction: .up
                ),
                date: "Last month"
            )
        ),
        chartData: .linear,
        topPrice: "$ 1.84",
        bottom: .init(
            bottomPrice: "$ 1.22",
            substrate: .init(
                leftValue: "12 APR",
                middleValue: "18 APR",
                style: .active
            )
        ),
        buttons: .buttons(periods(selectedIndex: 3))
    )

    static let componentSkeleton = ChartView.Config(
        header: .shimmer,
        chartData: .skeleton,
        topPrice: "",
        bottom: .init(
            bottomPrice: "",
            substrate: .init(
                leftValue: "",
                middleValue: "",
                style: .skeleton
            )
        ),
        buttons: .shimmer(
            count: periods(selectedIndex: 2).count
        )
    )

    static func periods(selectedIndex: Int) -> [ChartBottomButtonsView.Config.Button] {
        return ["H", "D", "W", "M", "6M", "Y"].enumerated().map { index, title in
            ChartBottomButtonsView.Config.Button(
                title: title,
                isSelected: index == selectedIndex,
                tapAction: {}
            )
        }
    }
}

private extension TKLineChartCanvasView.ChartData {
    static let linear = TKLineChartCanvasView.ChartData(
        mode: .linear,
        coordinates: PreviewData.coordinates
    )

    static let stepped = TKLineChartCanvasView.ChartData(
        mode: .stepped,
        coordinates: PreviewData.coordinates,
        smoothing: .none
    )

    static let skeleton = TKLineChartCanvasView.ChartData(
        mode: .linear,
        coordinates: PreviewData.skeletonCoordinates,
        style: .skeleton
    )
}

private enum PreviewData {
    static let coordinates: [Coordinate] = [
        PreviewCoordinate(x: 0, y: 1.42),
        PreviewCoordinate(x: 1, y: 1.39),
        PreviewCoordinate(x: 2, y: 1.43),
        PreviewCoordinate(x: 3, y: 1.41),
        PreviewCoordinate(x: 4, y: 1.48),
        PreviewCoordinate(x: 5, y: 1.52),
        PreviewCoordinate(x: 6, y: 1.49),
        PreviewCoordinate(x: 7, y: 1.61),
        PreviewCoordinate(x: 8, y: 1.74),
        PreviewCoordinate(x: 9, y: 1.69),
        PreviewCoordinate(x: 10, y: 1.75),
        PreviewCoordinate(x: 11, y: 1.72),
        PreviewCoordinate(x: 12, y: 1.68),
        PreviewCoordinate(x: 13, y: 1.74),
        PreviewCoordinate(x: 14, y: 1.93),
        PreviewCoordinate(x: 15, y: 1.89),
        PreviewCoordinate(x: 16, y: 1.95),
        PreviewCoordinate(x: 17, y: 1.91),
    ]

    static let skeletonCoordinates: [Coordinate] = [
        PreviewCoordinate(x: 0.0, y: 40.5),
        PreviewCoordinate(x: 4.0, y: 40.5),
        PreviewCoordinate(x: 16.0, y: 16.5),
        PreviewCoordinate(x: 28.0, y: 20.5),
        PreviewCoordinate(x: 40.0, y: 8.5),
        PreviewCoordinate(x: 52.0, y: 14.5),
        PreviewCoordinate(x: 64.0, y: 13.5),
        PreviewCoordinate(x: 76.0, y: 23.5),
        PreviewCoordinate(x: 88.0, y: 5.5),
        PreviewCoordinate(x: 100.0, y: 55.5),
        PreviewCoordinate(x: 112.0, y: 57.5),
        PreviewCoordinate(x: 124.0, y: 71.5),
        PreviewCoordinate(x: 136.0, y: 0.0),
        PreviewCoordinate(x: 148.0, y: 18.5),
        PreviewCoordinate(x: 160.0, y: 25.5),
        PreviewCoordinate(x: 172.0, y: 5.5),
        PreviewCoordinate(x: 184.0, y: 17.5),
        PreviewCoordinate(x: 196.0, y: 15.5),
        PreviewCoordinate(x: 207.0, y: 38.5),
        PreviewCoordinate(x: 218.0, y: 36.5),
        PreviewCoordinate(x: 232.0, y: 56.5),
        PreviewCoordinate(x: 244.0, y: 63.5),
        PreviewCoordinate(x: 255.5, y: 84.5),
        PreviewCoordinate(x: 268.0, y: 71.5),
        PreviewCoordinate(x: 280.0, y: 75.5),
        PreviewCoordinate(x: 292.0, y: 95.5),
        PreviewCoordinate(x: 304.0, y: 141.5),
        PreviewCoordinate(x: 316.0, y: 145.5),
        PreviewCoordinate(x: 328.0, y: 130.5),
        PreviewCoordinate(x: 340.0, y: 164.5),
        PreviewCoordinate(x: 350.0, y: 150.5),
        PreviewCoordinate(x: 362.0, y: 153.5),
        PreviewCoordinate(x: 372.0, y: 124.5),
        PreviewCoordinate(x: 380.0, y: 144.5),
        PreviewCoordinate(x: 390.0, y: 144.5),
    ]
}

#Preview {
    ChartPreviews()
        .debugPreview(background: .page)
        .tkThemed()
}
