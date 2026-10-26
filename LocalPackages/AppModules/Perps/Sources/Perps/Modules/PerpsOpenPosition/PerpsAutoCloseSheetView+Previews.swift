import SwiftUI
import TKUIKit

private final class PerpsAutoCloseSheetPreviewViewModel: PerpsAutoCloseSheetViewModeling {
    @Published var takeProfitPercentText = "25"
    @Published var takeProfitPriceText = "83,880.25"
    @Published var stopLossPercentText = ""
    @Published var stopLossPriceText = ""
    let takeProfitPercentSign: FloatingPointSign = .plus
    let stopLossPercentSign: FloatingPointSign = .minus
    let takeProfitPresets: [Double] = [25, 50, 75, 100]
    let stopLossPresets: [Double] = [10, 25, 50, 75]
    let takeProfitWarningText: String? = nil
    let stopLossWarningText: String? = "Stop loss is below the liquidation price"
    let takeProfitExpectedText = "Expected profit ≈ +$50"
    let stopLossExpectedText = "Expected loss ≈ −$10"
    let submitErrorText: String? = nil
    let isSubmitting = false
    let isApplyEnabled = true

    func displayText(_ rawText: String) -> String {
        rawText
    }

    func setTakeProfitPercent(_ text: String) {
        takeProfitPercentText = text
    }

    func setTakeProfitPrice(_ text: String) {
        takeProfitPriceText = text
    }

    func setStopLossPercent(_ text: String) {
        stopLossPercentText = text
    }

    func setStopLossPrice(_ text: String) {
        stopLossPriceText = text
    }

    func applyTakeProfitPreset(_ percent: Double) {
        takeProfitPercentText = "\(Int(percent))"
    }

    func applyStopLossPreset(_ percent: Double) {
        stopLossPercentText = "\(Int(percent))"
    }

    func apply() {}
}

@available(iOS 17.0, *)
#Preview("Auto close", traits: .sizeThatFitsLayout) {
    PerpsAutoCloseSheetView(viewModel: PerpsAutoCloseSheetPreviewViewModel())
        .frame(width: 390)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}
