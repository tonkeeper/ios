import SwiftUI

struct ChartTopPriceView: View {
    var config: Config

    var body: some View {
        VStack(spacing: 0) {
            ChartPriceText(
                priceText: config.priceText,
                textStyle: config.textStyle
            )
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(Layout.priceTextContentInsets)
            Spacer(minLength: 0)
        }
        .frame(height: Layout.height)
    }
}

extension ChartTopPriceView {
    struct Config {
        var textStyle: TKTextStyle
        var priceText: String
    }

    enum Layout {
        static let height: CGFloat = 20
        static let priceTextContentInsets = EdgeInsets(
            top: 0,
            leading: 32,
            bottom: 0,
            trailing: 16
        )
    }
}

#Preview {
    ChartTopPriceView(
        config: ChartTopPriceView.Config(
            textStyle: TKTextStyle(
                font: .monospacedSystemFont(
                    ofSize: 12,
                    weight: .medium
                ),
                lineHeight: 16
            ),
            priceText: "123"
        )
    )
    .showSize()
    .border(.cyan)
    .debugPreview()
}
