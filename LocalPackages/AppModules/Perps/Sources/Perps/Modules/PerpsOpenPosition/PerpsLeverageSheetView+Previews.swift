import SwiftUI
import TKUIKit

private final class PerpsLeverageSheetPreviewViewModel: PerpsLeverageSheetViewModeling {
    @Published var leverage: Double = 10
    let minLeverage = 1
    let maxLeverage = 40

    var leverageText: String {
        "\(Int(leverage))x"
    }

    var liquidationText: String? {
        "$60,393.78"
    }

    func setLeverage(_ value: Double) {
        leverage = value
    }

    func setMin() {
        leverage = Double(minLeverage)
    }

    func setMax() {
        leverage = Double(maxLeverage)
    }

    func apply() {}
}

@available(iOS 17.0, *)
#Preview("Leverage", traits: .sizeThatFitsLayout) {
    PerpsLeverageSheetView(viewModel: PerpsLeverageSheetPreviewViewModel())
        .frame(width: 390)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}
