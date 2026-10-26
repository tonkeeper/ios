import SwiftUI
import TKLocalize
import TKUIKit

public struct PerpsOpenPositionsCard: View {
    var total: PerpsPositionsTotal?
    let positions: [PerpsPositionRowItem]
    let onSelect: (Int64) -> Void

    public init(
        total: PerpsPositionsTotal? = nil,
        positions: [PerpsPositionRowItem],
        onSelect: @escaping (Int64) -> Void
    ) {
        self.total = total
        self.positions = positions
        self.onSelect = onSelect
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
                    total: positions.count,
                    leadingInset: Layout.separatorLeadingInset
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .fill(.backgroundContent)
        )
    }

    private func totalHeader(_ total: PerpsPositionsTotal) -> some View {
        let pnlColor: TKColor = total.isPnlPositive ? .accentGreen : .accentRed
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
