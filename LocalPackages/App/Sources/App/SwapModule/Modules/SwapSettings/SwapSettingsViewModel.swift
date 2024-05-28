import Foundation
import KeeperCore

protocol SwapSettingsModuleOutput: AnyObject {
  var didFinish: (() -> Void)? { get set }
  var didTapSave: ((SwapSettingsModel) -> Void)? { get set }
}

protocol SwapSettingsViewModel: AnyObject {
  var didUpdateModel: ((SwapSettingsView.Model) -> Void)? { get set }
  var didUpdateSlippageState: ((SlippageInputContainerView.SlippageState) -> Void)? { get set }
  var slippagePercentageTextFormatter: SlippagePercentageTextFieldFormatter { get }
  
  func viewDidLoad()
}

final class SwapSettingsViewModelImplementation: SwapSettingsViewModel, SwapSettingsModuleOutput {
  
  // MARK: - SwapSettingsModuleOutput
  
  var didFinish: (() -> Void)?
  var didTapSave: ((SwapSettingsModel) -> Void)?
  
  // MARK: - SwapSettingsViewModel
  
  var didUpdateModel: ((SwapSettingsView.Model) -> Void)?
  var didUpdateSlippageState: ((SlippageInputContainerView.SlippageState) -> Void)?
  
  func viewDidLoad() {
    update()
  }
  
  // MARK: - State
  
  private let maximumSlippageValueDefault: Decimal = 50
  private let maximumSlippageValueExpert: Decimal = 100
  private var maximumSlippageInputValue: Decimal {
    isExpertModeEnabled ? maximumSlippageValueExpert : maximumSlippageValueDefault
  }
  
  private var currentSlippage: SlippageInputContainerView.SlippageState = .fixedPercent(.one)
  
  private var isExpertModeEnabled = false {
    didSet {
      didUpdateIsExpertModeEnabledState()
    }
  }
  
  // MARK: - Formatter
  
  let slippagePercentageTextFormatter: SlippagePercentageTextFieldFormatter = .createFormatter()
  
  // MARK: - Dependencies
  
  private let swapSettingsController: SwapSettingsController
  private var swapSettingsModel: SwapSettingsModel
  
  // MARK: - Init
  
  init(swapSettingsController: SwapSettingsController, swapSettingsModel: SwapSettingsModel) {
    self.swapSettingsController = swapSettingsController
    self.swapSettingsModel = swapSettingsModel
    self.currentSlippage = self.mapSlippageTolerance(swapSettingsModel.slippageTolerance)
    self.slippagePercentageTextFormatter.maximumFractionDigits = 1
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension SwapSettingsViewModelImplementation {
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> SwapSettingsView.Model {
    SwapSettingsView.Model(
      title: ModalTitleView.Model(
        title: "Settings"
      ),
      slippageTitleDescription: createTitleDescription(
        title: "Slippage",
        description: "The amount the price can change unfavorably before the trade reverts"
      ),
      slippageInputContainer: SlippageInputContainerView.Model(
        textFieldplaceholder: "Custom %",
        slippageState: currentSlippage,
        onSlippageChange: { [weak self] slippage in
          self?.currentSlippage = slippage
        }
      ),
      expertModeContainer: SwapSettingsExpertModeContainer.Model(
        titleDescription: createTitleDescription(
          title: "Expert Mode",
          description: "Allows high price impact trades. Use at your own risk."
        ),
        switcher: SwapSettingsExpertModeContainer.Model.Switcher(
          isOn: false,
          action: { [weak self] isOn in
            self?.isExpertModeEnabled = isOn
          }
        )
      ),
      saveButton: SwapSettingsView.Model.Button(
        title: "Save",
        isEnabled: true,
        action: { [weak self] in
          guard let self else { return }
          didTapSave?(createSettingsModel())
          didFinish?()
        }
      )
    )
  }
  
  func createTitleDescription(title: String, description: String) -> SwapSettingsTitleDecriptionView.Model {
    SwapSettingsTitleDecriptionView.Model(
      title: title.withTextStyle(.label1, color: .Text.primary),
      description: description.withTextStyle(.body2, color: .Text.secondary)
    )
  }
  
  func createSettingsModel() -> SwapSettingsModel {
    SwapSettingsModel(
      slippageTolerance: SlippageTolerance(
        percent: currentSlippage.decimalValue ?? 1
      )
    )
  }
  
  func mapSlippageTolerance(_ slippageTolerance: SlippageTolerance) ->  SlippageInputContainerView.SlippageState {
    if let fixed = SlippageInputContainerView.SlippageState.Fixed(rawValue: slippageTolerance.percent) {
      return .fixedPercent(fixed)
    } else {
      return .customPercent("\(slippageTolerance.percent)")
    }
  }
  
  func didUpdateIsExpertModeEnabledState() {
    slippagePercentageTextFormatter.maximumInputValue = maximumSlippageInputValue
    if let currentValue = currentSlippage.decimalValue, !isSlippageValueValid(currentValue) {
      didUpdateSlippageState?(.customPercent("\(maximumSlippageInputValue)"))
    }
  }
  
  func isSlippageValueValid(_ value: Decimal) -> Bool {
    return value <= maximumSlippageInputValue
  }
}

private extension SlippagePercentageTextFieldFormatter {
  static func createFormatter() -> SlippagePercentageTextFieldFormatter {
    let numberFormatter = NumberFormatter()
    numberFormatter.decimalSeparator = "."
    return SlippagePercentageTextFieldFormatter(
      numberFormatter: numberFormatter
    )
  }
}
