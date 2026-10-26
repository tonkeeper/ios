import SwiftUI
import TKUIKit

public struct PerpsLimitOrdersCard: View {
    let orders: [PerpsLimitOrderRowItem]
    let onSelect: (Int64) -> Void

    public init(orders: [PerpsLimitOrderRowItem], onSelect: @escaping (Int64) -> Void) {
        self.orders = orders
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(orders.enumerated()), id: \.element.id) { index, order in
                Button(action: { onSelect(order.marketId) }) {
                    PerpsPositionRowView(order: order)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .applySeparatorIfNeeded(
                    index: index,
                    total: orders.count,
                    leadingInset: Layout.separatorLeadingInset
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .fill(.backgroundContent)
        )
    }
}

private enum Layout {
    static let separatorLeadingInset: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
}
