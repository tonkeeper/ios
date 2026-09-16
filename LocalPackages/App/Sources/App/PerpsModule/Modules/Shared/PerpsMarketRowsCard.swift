import SwiftUI
import TKUIKit

struct PerpsMarketRowsCard: View {
    let markets: [PerpsMarketRowItem]
    var isLoadingNextPage = false
    let onSelect: (Int64) -> Void
    var onRowAppear: (Int64) -> Void = { _ in }
    var onRowDisappear: (Int64) -> Void = { _ in }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(markets.enumerated()), id: \.element.id) { index, market in
                Button(action: { onSelect(market.id) }) {
                    PerpsMarketRowView(market: market)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onAppear { onRowAppear(market.id) }
                .onDisappear { onRowDisappear(market.id) }
                .applySeparatorIfNeeded(
                    index: index,
                    total: markets.count,
                    leadingInset: Layout.separatorLeadingInset
                )
            }
            if isLoadingNextPage {
                HStack {
                    Spacer()
                    CircularLoader(mode: .indeterminate, preset: .medium)
                        .padding(.vertical, Layout.loaderVerticalPadding)
                    Spacer()
                }
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
    static let loaderVerticalPadding: CGFloat = 16
}
