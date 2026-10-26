import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Limit order busy", traits: .sizeThatFitsLayout) {
    PerpsLimitOrderBusyPreview()
        .frame(width: 390)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

private struct PerpsLimitOrderBusyPreview: View {
    @State private var isBusy = true
    @State private var canCancelOrders = true

    var body: some View {
        VStack(spacing: 16) {
            Toggle("Order change in progress", isOn: $isBusy)
                .padding(.horizontal, 16)
            Toggle("Cancel allowed", isOn: $canCancelOrders)
                .padding(.horizontal, 16)
            PerpsAssetLimitOrdersSection(
                orders: [.init(
                    id: "1",
                    orderIndex: 1,
                    limitPriceText: "$64,000.00",
                    captionText: "Limit price · Expires 13 Oct",
                    sideText: "Long",
                    isLong: true
                )],
                isEnabled: canCancelOrders && !isBusy,
                isBusy: isBusy,
                onLimitOrder: { _ in }
            )
            PerpsAssetStickyActions(
                actions: .editCancelLimitOrder(orderIndex: 1, enabled: canCancelOrders && !isBusy),
                isLimitOrderBusy: isBusy,
                onLong: {},
                onShort: {},
                onEdit: {},
                onCashOut: {},
                onEditLimitOrder: { _ in },
                onCancelLimitOrder: { _ in }
            )
            .frame(height: 96)
        }
        .padding(.top, 16)
    }
}
