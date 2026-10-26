import Foundation

@MainActor
public protocol PerpsAutoCloseSheetViewModeling: ObservableObject {
    var takeProfitPercentText: String { get }
    var takeProfitPriceText: String { get }
    var stopLossPercentText: String { get }
    var stopLossPriceText: String { get }
    var takeProfitPercentSign: FloatingPointSign { get }
    var stopLossPercentSign: FloatingPointSign { get }
    var takeProfitPresets: [Double] { get }
    var stopLossPresets: [Double] { get }
    var takeProfitWarningText: String? { get }
    var stopLossWarningText: String? { get }
    var takeProfitExpectedText: String { get }
    var stopLossExpectedText: String { get }
    var submitErrorText: String? { get }
    var isSubmitting: Bool { get }
    var isApplyEnabled: Bool { get }

    /// A field shows the raw keystrokes while it is focused and this rendering
    /// once it is not, so the venue formatter stays on the bound side.
    func displayText(_ rawText: String) -> String

    func setTakeProfitPercent(_ text: String)
    func setTakeProfitPrice(_ text: String)
    func setStopLossPercent(_ text: String)
    func setStopLossPrice(_ text: String)
    func applyTakeProfitPreset(_ percent: Double)
    func applyStopLossPreset(_ percent: Double)
    func apply()
}
