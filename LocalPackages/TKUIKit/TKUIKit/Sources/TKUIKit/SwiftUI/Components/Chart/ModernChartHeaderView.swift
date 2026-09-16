import SwiftUI
import UIKit

public struct ModernChartHeaderView: View {
    @Environment(\.tkPalette) private var palette

    @ObservedObject private var store: ConfigurationStore

    private var configuration: Configuration {
        store.configuration
    }

    public init(configuration: Configuration) {
        self.store = ConfigurationStore(configuration: configuration)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch configuration {
            case .shimmer:
                shimmerView
            case let .content(content):
                contentView(content)
            }
        }
        .frame(height: Layout.height)
        .padding(.leading, 24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var shimmerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ShimmerSwiftUIView(config: .init(cornerRadius: .capsule))
                .frame(width: 97, height: 32)
            ShimmerSwiftUIView(config: .init(cornerRadius: .capsule))
                .frame(width: 221, height: 16)
        }
    }

    @ViewBuilder
    private func contentView(_ content: Content) -> some View {
        Text(priceText(content))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

        HStack(alignment: .center, spacing: Layout.diffSpacing) {
            DiffValueText(
                value: diffText(content),
                animationStyle: content.diffAnimationStyle
            )
            DiffValueText(
                value: priceDiffText(content),
                animationStyle: content.diffAnimationStyle
            )
            Text(dateText(content))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, 2)
        }
        .padding(.top, 5)

        Spacer(minLength: 0)
    }

    private func priceText(_ content: Content) -> AttributedString {
        AttributedString(
            content.price.withTextStyle(
                Layout.priceTextStyle,
                color: UIColor(palette.text.primary),
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            ).replaceMonospaceSpaces()
        )
    }

    private func dateText(_ content: Content) -> AttributedString {
        AttributedString(
            content.date.withTextStyle(
                Layout.otherTextStyle,
                color: UIColor(palette.text.secondary),
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
        )
    }

    private func diffText(_ content: Content) -> AttributedString {
        AttributedString(
            content.diff.diff.withTextStyle(
                Layout.otherTextStyle,
                color: UIColor(diffColor(content.diff.direction)),
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            ).replaceMonospaceSpaces()
        )
    }

    private func priceDiffText(_ content: Content) -> AttributedString {
        AttributedString(
            content.diff.priceDiff.withTextStyle(
                Layout.otherTextStyle,
                color: UIColor(diffColor(content.diff.direction).opacity(0.44)),
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            ).replaceMonospaceSpaces()
        )
    }

    private func diffColor(_ direction: Diff.Direction) -> Color {
        switch direction {
        case .up:
            palette.accent.green
        case .down:
            palette.accent.red
        case .none:
            palette.text.secondary
        }
    }
}

public extension ModernChartHeaderView {
    enum Layout {
        static let height: CGFloat = 58
        static let diffSpacing: CGFloat = 8

        static let priceTextStyle = TKTextStyle(
            font: .tkBold(size: 24, features: .display),
            lineHeight: 32
        )
        static let otherTextStyle = TKTextStyle(
            font: .tkRegular(size: 14, features: .text),
            lineHeight: 20
        )
    }

    enum DiffAnimationStyle: Hashable {
        case none
        case rollingNumbers
    }

    struct Diff: Hashable {
        public enum Direction: Hashable {
            case up
            case down
            case none
        }

        public let diff: String
        public let priceDiff: String
        public let direction: Direction

        public init(diff: String, priceDiff: String, direction: Direction) {
            self.diff = diff
            self.priceDiff = priceDiff
            self.direction = direction
        }
    }

    final class ConfigurationStore: ObservableObject {
        @Published public var configuration: Configuration

        public init(configuration: Configuration) {
            self.configuration = configuration
        }
    }

    struct Content: Hashable {
        public let price: String
        public let diff: Diff
        public let date: String
        public let diffAnimationStyle: DiffAnimationStyle

        public init(
            price: String,
            diff: Diff,
            date: String,
            diffAnimationStyle: DiffAnimationStyle = .none
        ) {
            self.price = price
            self.diff = diff
            self.date = date
            self.diffAnimationStyle = diffAnimationStyle
        }
    }

    enum Configuration: Hashable {
        case shimmer
        case content(Content)
    }
}

private struct DiffValueText: View {
    let value: AttributedString
    let animationStyle: ModernChartHeaderView.DiffAnimationStyle

    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                Text(value)
                    .contentTransition(.numericText())
                    .transaction { transaction in
                        if animationStyle == .none {
                            transaction.animation = nil
                        }
                    }
                    .animation(
                        animationStyle == .rollingNumbers
                            ? .easeInOut(duration: 0.15)
                            : nil,
                        value: value
                    )
            } else {
                Text(value)
            }
        }
        .lineLimit(1)
    }
}

private extension NSAttributedString {
    func replaceMonospaceSpaces() -> NSAttributedString {
        let str = NSMutableAttributedString(attributedString: self)
        let regex = try? NSRegularExpression(pattern: " ", options: [])
        let range = NSMakeRange(0, str.string.count)
        guard let matches = regex?.matches(in: str.string, range: range) else {
            return str
        }

        for match in matches.reversed() {
            str.addAttributes([.font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)], range: match.range)
        }

        return str
    }
}

#Preview("Below Diff") {
    VStack(spacing: 12) {
        ModernChartHeaderView(
            configuration: .content(
                .init(
                    price: "$ 1.24",
                    diff: .init(
                        diff: "+0.30%",
                        priceDiff: "$ 0.00396",
                        direction: .up
                    ),
                    date: "Price"
                )
            )
        )
        .border(TKPreview.palette.separator.common)

        ModernChartHeaderView(
            configuration: .content(
                .init(
                    price: "$ 1.846",
                    diff: .init(
                        diff: "+7.32%",
                        priceDiff: "+$ 0.41",
                        direction: .up
                    ),
                    date: "Last month"
                )
            )
        )
        .border(TKPreview.palette.separator.common)

        ModernChartHeaderView(
            configuration: .shimmer
        )
        .border(TKPreview.palette.separator.common)
    }
    .debugPreview(background: .page)
}
