import SwiftUI
import TKUIKit
import UIKit

private final class PerpsAutoCloseSheetPreviewViewModel: PerpsAutoCloseSheetViewModeling {
    @Published var takeProfitPercentText = "25"
    @Published var takeProfitPriceText = "83,880.25"
    @Published var stopLossPercentText = ""
    @Published var stopLossPriceText = ""
    let takeProfitPercentSign: FloatingPointSign = .plus
    let stopLossPercentSign: FloatingPointSign = .minus
    let takeProfitPresets: [Double] = [25, 50, 75, 100]
    let stopLossPresets: [Double] = [10, 25, 50, 75]
    var takeProfitWarningText: String?
    var stopLossWarningText: String? = "The Stop Loss value is close to the liquidation price ($82.44) and may not execute."
    let stopLossLiquidationText: String? = "Liquidation at $82.44"
    let takeProfitExpectedText = "Expected profit ≈ +$50"
    let stopLossExpectedText = "Expected loss ≈ −$10"
    var submitErrorText: String?
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

@MainActor
private final class AutoCloseSheetPreviewController: UIViewController {
    var showsWarnings = false
    private var hasPresented = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPresented else { return }
        hasPresented = true
        let viewModel = PerpsAutoCloseSheetPreviewViewModel()
        viewModel.stopLossWarningText = nil
        if showsWarnings {
            viewModel.takeProfitWarningText = "Значение тейк-профита должно быть выше текущей цены."
            viewModel.stopLossWarningText = "Ликвидация наступит раньше, при $76 170,6. Установите стоп-лосс выше."
            viewModel.submitErrorText = "Не удалось задать автозакрытие. Попробуйте ещё раз."
        }
        let content = TKBottomSheetScrollHostingController(
            title: "Автозакрытие",
            subtitle: "Текущая цена $76 763,4",
            liveSubtitle: nil
        ) {
            PerpsAutoCloseSheetView(viewModel: viewModel)
                .tkPreviewTheme(.deepBlue)
        }
        let sheet = TKBottomSheetViewController(contentViewController: content)
        sheet.keyboardObserver = TKBottomSheetKeyboardObserver(bottomSheet: sheet)
        sheet.present(fromViewController: self)
    }
}

@available(iOS 17.0, *)
#Preview("Sheet without warnings") {
    AutoCloseSheetPreviewController()
}

@available(iOS 17.0, *)
#Preview("Sheet with warnings") {
    let controller = AutoCloseSheetPreviewController()
    controller.showsWarnings = true
    return controller
}
