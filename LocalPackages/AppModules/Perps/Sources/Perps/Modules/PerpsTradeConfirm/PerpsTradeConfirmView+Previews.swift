import SwiftUI
import TKUIKit

private final class PerpsTradeConfirmPreviewViewModel: PerpsTradeConfirmViewModeling {
    let rows: [PerpsTradeConfirmRow]
    let isConfirmationEnabled: Bool
    let isProcessing: Bool
    let titleText = "Long BTC"
    let iconLetter = "B"
    let iconURL: URL? = nil

    init(rows: [PerpsTradeConfirmRow], isConfirmationEnabled: Bool, isProcessing: Bool = false) {
        self.rows = rows
        self.isConfirmationEnabled = isConfirmationEnabled
        self.isProcessing = isProcessing
    }

    func onAppear() {}
    func onDisappear() {}
    func back() {}
    func close() {}
    func editAutoClose() {}
    func confirm() {}
}

private let previewRows = [
    PerpsTradeConfirmRow(id: .youPay, title: "You pay", value: "$20.00", subValue: nil),
    PerpsTradeConfirmRow(id: .entry, title: "Entry price", value: "$66,021.17", subValue: nil),
    PerpsTradeConfirmRow(id: .leverage, title: "Leverage", value: "27x", subValue: nil),
    PerpsTradeConfirmRow(
        id: .liquidation,
        title: "Liquidation price",
        value: "$64,141.75",
        subValue: "−2.85%",
        tone: .negative
    ),
    PerpsTradeConfirmRow(id: .size, title: "Size", value: "$540.00", subValue: "0.008 BTC"),
    PerpsTradeConfirmRow(id: .fee, title: "Fee", value: "$0.14", subValue: "≈ 0.14 USD", tone: .tertiary),
    PerpsTradeConfirmRow(
        id: .autoClose,
        title: "Auto close",
        value: "Set",
        subValue: nil,
        tone: .accent,
        showsChevron: true
    ),
]

#Preview("Deep Blue") {
    PerpsTradeConfirmView(
        viewModel: PerpsTradeConfirmPreviewViewModel(rows: previewRows, isConfirmationEnabled: true)
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Disabled") {
    PerpsTradeConfirmView(
        viewModel: PerpsTradeConfirmPreviewViewModel(rows: previewRows, isConfirmationEnabled: false)
    )
    .tkPreviewTheme(.light)
}

#Preview("Processing") {
    PerpsTradeConfirmView(
        viewModel: PerpsTradeConfirmPreviewViewModel(rows: previewRows, isConfirmationEnabled: false, isProcessing: true)
    )
    .tkPreviewTheme(.deepBlue)
}
