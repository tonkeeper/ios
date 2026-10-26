import SwiftUI
import TKUIKit

private extension MoonPayPaymentStatusViewState {
    static func preview(
        steps: [Step],
        actionTitle: String? = nil
    ) -> MoonPayPaymentStatusViewState {
        MoonPayPaymentStatusViewState(
            title: "Payment status",
            steps: steps,
            summary: [
                .init(id: "paid", title: "You paid", value: "€38 500.00"),
                .init(id: "receive", title: "You receive", value: "0.4869 BTC", isHighlighted: true),
                .init(id: "order", title: "Order ID", value: "mp_7f3c9a21"),
            ],
            feesTitle: "Fees",
            feesValue: "€2 177.01",
            feeDetails: [
                .init(id: "moonpay", title: "MoonPay", value: "€1 500.00"),
                .init(id: "network", title: "Network", value: "€677.01"),
            ],
            showsDetails: actionTitle == nil,
            actionTitle: actionTitle
        )
    }
}

#Preview("Pending") {
    MoonPayPaymentStatusView(
        state: .preview(steps: [
            .init(id: "started", title: "Payment started", subtitle: "Visa •••• 4148 · €38 500.00 authorised", status: .done),
            .init(id: "pending", title: "Payment pending", subtitle: "Clearing with the network", status: .inProgress),
            .init(id: "completed", title: "Payment completed", subtitle: "0.4869 BTC in your wallet", status: .waiting),
        ]),
        onAction: {},
        onClose: {}
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Declined") {
    MoonPayPaymentStatusView(
        state: .preview(
            steps: [
                .init(id: "started", title: "Payment declined", subtitle: "Your bank declined it. No charge", status: .failed),
                .init(id: "pending", title: "Payment pending", subtitle: "Clearing with the network", status: .waiting),
                .init(id: "completed", title: "Payment completed", subtitle: "0.4869 BTC in your wallet", status: .waiting),
            ],
            actionTitle: "Try another card"
        ),
        onAction: {},
        onClose: {}
    )
    .tkPreviewTheme(.deepBlue)
}
