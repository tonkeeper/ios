import SwiftUI
import TKLocalize
import TKUIKit

public struct PerpsOpenPositionsCard: View {
    var total: PerpsPositionsTotal?
    let positions: [PerpsPositionRowItem]
    var more: PerpsMorePositions?
    let onSelect: (Int64) -> Void
    var onMore: () -> Void

    public init(
        total: PerpsPositionsTotal? = nil,
        positions: [PerpsPositionRowItem],
        more: PerpsMorePositions? = nil,
        onSelect: @escaping (Int64) -> Void,
        onMore: @escaping () -> Void = {}
    ) {
        self.total = total
        self.positions = positions
        self.more = more
        self.onSelect = onSelect
        self.onMore = onMore
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let total {
                totalHeader(total)

                Rectangle()
                    .fill(.separatorCommon)
                    .frame(height: TKUIKit.Constants.separatorWidth)
            }

            ForEach(Array(positions.enumerated()), id: \.element.id) { index, position in
                Button(action: { onSelect(position.id) }) {
                    PerpsPositionRowView(position: position)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .applySeparatorIfNeeded(
                    index: index,
                    total: positions.count + (more == nil ? 0 : 1),
                    leadingInset: Layout.separatorLeadingInset
                )
            }

            if let more {
                Button(action: onMore) {
                    PerpsMorePositionsRow(more: more)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("perps_more_positions")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .fill(.backgroundContent)
        )
    }

    private func totalHeader(_ total: PerpsPositionsTotal) -> some View {
        let pnlColor: TKColor = total.isPnlPositive.map { $0 ? .accentGreen : .accentRed } ?? .textSecondary
        return VStack(alignment: .leading, spacing: 0) {
            Text(TKLocales.Perps.totalAmount)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
            Text(total.amountText)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
            HStack(spacing: Layout.deltaSpacing) {
                Text(total.pnlText)
                    .textStyle(.body2)
                    .foregroundStyle(pnlColor)
                if let percent = total.pnlPercentText {
                    Text(percent)
                        .textStyle(.body2)
                        .foregroundStyle(pnlColor)
                        .opacity(Layout.deltaAmountOpacity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Layout.cellPadding)
    }
}

private extension PerpsOpenPositionsCard {
    enum Layout {
        static let cellPadding: CGFloat = 16
        static let cardCornerRadius: CGFloat = 16
        static let separatorLeadingInset: CGFloat = 16
        static let deltaSpacing: CGFloat = 8
        static let deltaAmountOpacity: Double = 0.48
    }
}
