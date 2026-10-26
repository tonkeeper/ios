import SwiftUI
import TKUIKit

public struct PerpsPositionRowView: View {
    private let symbol: String
    private let iconURL: URL?
    private let leverageText: String?
    private let sideText: String
    private let isLong: Bool
    private let valueText: String
    private let detailText: String
    private let detailColor: TKColor

    public init(position: PerpsPositionRowItem) {
        symbol = position.symbol
        iconURL = position.iconURL
        leverageText = position.leverageText
        sideText = position.sideText
        isLong = position.isLong
        valueText = position.valueText
        detailText = position.pnlText
        detailColor = position.isPnlPositive.map { $0 ? .accentGreen : .accentRed } ?? .textSecondary
    }

    init(order: PerpsLimitOrderRowItem) {
        symbol = order.symbol
        iconURL = order.iconURL
        leverageText = nil
        sideText = order.sideText
        isLong = order.isLong
        valueText = order.valueText
        detailText = order.limitText
        detailColor = .textSecondary
    }

    public var body: some View {
        HStack(spacing: 0) {
            icon

            HStack(spacing: 0) {
                Text(symbol)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let leverage = leverageText {
                    TKTagSwiftUIView(config: .tag(text: leverage))
                }
                TKTagSwiftUIView(config: .accentTag(
                    text: sideText,
                    accent: isLong ? .accentGreen : .accentRed
                ))
            }
            .padding(.leading, Layout.cellPadding)

            Spacer(minLength: Layout.cellPadding)

            VStack(alignment: .trailing, spacing: 0) {
                Text(valueText)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                Text(detailText)
                    .textStyle(.body2)
                    .foregroundStyle(detailColor)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, Layout.cellPadding)
        .padding(.vertical, Layout.rowVerticalPadding)
    }

    @ViewBuilder
    private var icon: some View {
        if let iconURL {
            AssetAvatarView(imageSource: .url(iconURL), size: .small)
        } else {
            ZStack {
                Circle()
                    .fill(.backgroundContentTint)
                Text(String(symbol.prefix(1)))
                    .textStyle(.label2)
                    .foregroundStyle(.textSecondary)
            }
            .frame(width: Layout.iconSide, height: Layout.iconSide)
        }
    }
}

private extension PerpsPositionRowView {
    enum Layout {
        static let cellPadding: CGFloat = 16
        static let iconSide: CGFloat = 44
        static let rowVerticalPadding: CGFloat = 16
    }
}
