import SwiftUI

struct ChartBottomPriceView: View {
    var config: Config

    var body: some View {
        VStack(spacing: 0) {
            ChartPriceText(
                priceText: config.priceText,
                textStyle: config.textStyle
            )
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(Layout.priceTextInsets)
            Spacer(minLength: 0)
        }
        .frame(height: Layout.height)
        .overlay {
            GeometryReader { proxy in
                Text(config.leadingDate)
                    .textStyle(config.textStyle)
                    .foregroundStyle(.textSecondary)
                    .offset(
                        x: leftAxisLabelX(in: proxy.size.width),
                        y: axisLabelY(in: proxy.size.height)
                    )
                Text(config.middleDate)
                    .textStyle(config.textStyle)
                    .foregroundStyle(.textSecondary)
                    .offset(
                        x: middleAxisLabelX(in: proxy.size.width),
                        y: axisLabelY(in: proxy.size.height)
                    )
            }
        }
    }
}

extension ChartBottomPriceView {
    struct Config {
        var textStyle: TKTextStyle
        var priceText: String
        var leadingDate: String
        var middleDate: String
    }

    enum Layout {
        static let height: CGFloat = 44
        static let priceTextInsets = EdgeInsets(
            top: 4,
            leading: 32,
            bottom: 0,
            trailing: 16
        )

        static let axisDivisionCount = 5
        static let axisLabelHorizontalOffset: CGFloat = 6
        static let axisLabelBottomOffset: CGFloat = 2
    }

    func leftAxisLabelX(in width: CGFloat) -> CGFloat {
        let offset = width / CGFloat(Layout.axisDivisionCount)
        return (offset / 2) + Layout.axisLabelHorizontalOffset
    }

    func middleAxisLabelX(in width: CGFloat) -> CGFloat {
        let offset = width / CGFloat(Layout.axisDivisionCount)
        return (offset / 2) + (offset * 2) + Layout.axisLabelHorizontalOffset
    }

    func axisLabelY(in height: CGFloat) -> CGFloat {
        height - config.textStyle.lineHeight - Layout.axisLabelBottomOffset
    }
}

#Preview {
    ChartBottomPriceView(
        config: ChartBottomPriceView.Config(
            textStyle: TKTextStyle(
                font: .monospacedSystemFont(
                    ofSize: 12,
                    weight: .medium
                ),
                lineHeight: 16
            ),
            priceText: "123",
            leadingDate: "lead",
            middleDate: "middle"
        )
    )
    .showSize()
    .border(.cyan)
    .debugPreview()
    .tkThemed()
}
