import SwiftUI
import TKUIKit

private final class PerpsSetLimitPricePreviewViewModel: PerpsSetLimitPriceViewModeling {
    @Published var amountText = "66,420.00"

    let referencePriceText = "$67,104.20"
    let fieldPrefix = "$"
    let fieldSuffix: String? = nil
    let warningText: String? = nil
    let chipText = "−1.02 %"
    let isSetEnabled = true

    var quickFills: [PerpsSetLimitPriceQuickFillItem] {
        [
            PerpsSetLimitPriceQuickFillItem(fill: .mid, title: "Mid", isActive: false),
            PerpsSetLimitPriceQuickFillItem(fill: .p1, title: "− 1 %", isActive: true),
            PerpsSetLimitPriceQuickFillItem(fill: .p2, title: "− 2 %", isActive: false),
            PerpsSetLimitPriceQuickFillItem(fill: .p5, title: "− 5 %", isActive: false),
        ]
    }

    func onAppear() {}
    func onDisappear() {}
    func setAmount(_ text: String) {
        amountText = text
    }

    func toggleInputMode() {}
    func applyQuickFill(_: PerpsSetLimitPriceQuickFill) {}
    func setLimit() {}
    func back() {}
    func close() {}
}

#Preview("Deep Blue") {
    PerpsSetLimitPriceView(viewModel: PerpsSetLimitPricePreviewViewModel())
        .tkPreviewTheme(.deepBlue)
}

#Preview("Light") {
    PerpsSetLimitPriceView(viewModel: PerpsSetLimitPricePreviewViewModel())
        .tkPreviewTheme(.light)
}
