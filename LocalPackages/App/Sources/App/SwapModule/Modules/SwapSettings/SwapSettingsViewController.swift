import UIKit
import TKLocalize
import TKUIKit

final class SwapSettingsViewController: GenericViewViewController<SwapSettingsView> {
  
  private let viewModel: SwapSettingsViewModel
  
  init(viewModel: SwapSettingsViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension SwapSettingsViewController {
  func setup() {
    title = TKLocales.SwapSettings.title
    setupRightCloseButton { [weak self] in
      self?.dismiss(animated: true)
    }
    let slippageVal = viewModel.settings.slippage
    customView.slippageAmountTextField.text = slippageVal == Float(Int(slippageVal)) ? "\(Int(slippageVal))" : "\(slippageVal)"
    for btn in customView.slippageSuggestionsView.arrangedSubviews {
      if Float(btn.tag) == viewModel.settings.slippage * 100 {
        (btn as? TKButton)?.isSelected = true
      }
    }
    customView.expertModeSwitch.isOn = viewModel.settings.expertMode
  }
  
  func setupBindings() {
    customView.saveButton.configuration.action = { [weak self] in
      guard let self else {return}
      viewModel.onSave(settings: SwapSettings(slippage: Float(customView.slippageAmountTextField.text ?? "1") ?? 1,
                                              expertMode: customView.expertModeSwitch.isOn))
      dismiss(animated: true)
    }
  }
}
