import SwiftUI

public struct TradingActivityView: View {
    public struct Delta {
        var title: String
        var isPositive: Bool

        public init(title: String, isPositive: Bool) {
            self.title = title
            self.isPositive = isPositive
        }
    }

    @Environment(\.tkPalette) private var palette

    let leftTitle: String
    let rightTitle: String
    let delta: Delta?
    let hintText: String?

    let sellText: String
    let buyText: String
    let buyFraction: CGFloat

    public init(
        leftTitle: String,
        rightTitle: String,
        delta: Delta?,
        sellText: String,
        buyText: String,
        buyFraction: CGFloat,
        hintText: String? = nil
    ) {
        self.leftTitle = leftTitle
        self.rightTitle = rightTitle
        self.delta = delta
        self.hintText = hintText
        self.sellText = sellText
        self.buyText = buyText
        self.buyFraction = buyFraction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Layout.headerSpacing) {
                Text(leftTitle)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)

                hintIconView

                Spacer(minLength: Layout.minimumSpacer)

                HStack(spacing: Layout.deltaSpacing) {
                    Text(rightTitle)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)

                    if let delta {
                        Text(delta.title)
                            .textStyle(.body1)
                            .foregroundStyle(
                                delta.isPositive ? palette.accent.green : palette.accent.red
                            )
                    }
                }
            }
            .padding(.top, Layout.headerTopPadding)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Layout.headerBottomPadding)

            GeometryReader { geometry in
                HStack(spacing: Layout.barSpacing) {
                    RoundedRectExt(radius: Layout.barCornerRadius, corners: [.topLeft, .bottomLeft])
                        .fill(.accentGreen)
                        .frame(
                            width: geometry.size.width * buyFraction,
                            height: Layout.barHeight
                        )

                    RoundedRectExt(radius: Layout.barCornerRadius, corners: [.topRight, .bottomRight])
                        .fill(.accentRed)
                        .frame(height: Layout.barHeight)
                }
            }
            .frame(height: Layout.barHeight)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Layout.barBottomPadding)

            HStack(spacing: Layout.footerSpacing) {
                Text(buyText)
                    .textStyle(.body2)
                    .foregroundStyle(.accentGreen)
                Spacer(minLength: Layout.minimumSpacer)
                Text(sellText)
                    .textStyle(.body2)
                    .foregroundStyle(.accentRed)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Layout.footerBottomPadding)
        }
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .fill(.backgroundContent)
        )
    }

    @ViewBuilder
    private var hintIconView: some View {
        if let hintText {
            HintButton(
                configuration: HintConfiguration(
                    position: HintPosition(
                        tailParameters: TKHintTextView.tailParameters,
                        horizontal: .default,
                        vertical: .init(absolute: 1),
                        direction: .bottomLeft
                    ),
                    maximumWidth: Layout.hintMaximumWidth,
                    animationStyle: .bouncing
                )
            ) { position in
                TKHintTextView(
                    text: hintText,
                    position: position
                )
            } label: {
                hintIcon
            }
        } else {
            hintIcon
        }
    }

    private var hintIcon: some View {
        SwiftUI.Image.TKUIKit.Icons.Size16.informationCircle
            .renderingMode(.template)
            .foregroundStyle(.textSecondary)
            .frame(width: Layout.hintIconSize, height: Layout.hintIconSize)
            .padding(.bottom, Layout.hintIconBottomPadding)
    }
}

extension TradingActivityView {
    enum Layout {
        static let hintIconSize: CGFloat = 16
        static let headerSpacing: CGFloat = 4
        static let deltaSpacing: CGFloat = 4
        static let minimumSpacer: CGFloat = 12
        static let headerTopPadding: CGFloat = 17
        static let horizontalPadding: CGFloat = 16
        static let headerBottomPadding: CGFloat = 16
        static let barSpacing: CGFloat = 4
        static let barCornerRadius: CGFloat = 99
        static let barHeight: CGFloat = 6
        static let barBottomPadding: CGFloat = 8
        static let footerSpacing: CGFloat = 8
        static let footerBottomPadding: CGFloat = 15
        static let cornerRadius: CGFloat = 16
        static let hintMaximumWidth: CGFloat = 200
        static let hintIconBottomPadding: CGFloat = 2
    }
}

#Preview {
    VStack(spacing: 12) {
        TradingActivityView(
            leftTitle: "Volume",
            rightTitle: "$ 91.48M",
            delta: TradingActivityView.Delta(
                title: "+2.86 %",
                isPositive: true
            ),
            sellText: "Sell · $ 18.2M",
            buyText: "Buy · $ 72.5M",
            buyFraction: 0.66,
            hintText: "The total volume of all transactions over the past 24 hours."
        )
        TradingActivityView(
            leftTitle: "Volume",
            rightTitle: "$ 91.48M",
            delta: TradingActivityView.Delta(
                title: "-2.86 %",
                isPositive: false
            ),
            sellText: "Sell · $ 18.2M",
            buyText: "Buy · $ 72.5M",
            buyFraction: 0.5
        )
        TradingActivityView(
            leftTitle: "Volume",
            rightTitle: "$ 91.48M",
            delta: nil,
            sellText: "Sell · $ 18.2M",
            buyText: "Buy · $ 72.5M",
            buyFraction: 0.1
        )
    }
    .padding(.horizontal, 16)
    .debugPreview(background: .page)
    .tkThemed()
}
