import UIKit
import TKUIKit
import KeeperCore
import TKLocalize

class BuyAndSellViewController: GenericViewViewController<BuyAndSellView>, KeyboardObserving {
  private let viewModel: BuyAndSellViewModel
  private lazy var segmentedControl: UnderlinedSegmentedControl = {
    let segmentedControl = UnderlinedSegmentedControl(items: [TKLocales.Buy.button_buy, TKLocales.Buy.button_sell])
    segmentedControl.selectedSegmentIndex = 0
    return segmentedControl
  }()
    
  // MARK: - Init

  init(viewModel: BuyAndSellViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
  
    setup()
    setupBindings()
    setupViewEvents()
    viewModel.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
    customView.amountView.amountTextField.becomeFirstResponder()
  }

  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  // MARK: - Keyboard
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration,
    let keyboardHeight = notification.keyboardSize?.height else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.keyboardHeight = keyboardHeight
      self.customView.layoutIfNeeded()
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.keyboardHeight = 0
      self.customView.layoutIfNeeded()
    }
  }
}

private extension BuyAndSellViewController {
  func setup() {
    navigationItem.titleView = segmentedControl
    
    var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    continueButtonConfiguration.content.title = .plainString(TKLocales.Actions.continue_action)
    customView.continueButton.configuration = continueButtonConfiguration
    
    segmentedControl.snp.makeConstraints { make in
      make.height.equalTo(34)
    }
    
    customView.amountView.amountTextField.delegate = viewModel.sendAmountTextFieldFormatter
    customView.amountView.tonLabel.text = TonInfo.symbol
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let self else { return }
      
      customView.continueButton.configuration.isEnabled = model.isContinueButtonEnabled
      customView.amountView.minAmountLabel.text = model.minAmountDisclaimer
      customView.amountView.minAmountLabel.textColor = model.isContinueButtonEnabled ? .Text.secondary : .Accent.red
      customView.amountView.convertedAmountLabel.text = model.convertedAmount
      customView.amountView.amountTextField.placeholder = model.amount.placeholder
      customView.amountView.convertedAmountLabel.isHidden = !model.isConvertedAmountShown
    }
  }
  
  func setupViewEvents() {
    customView.amountView.didUpdateText = { [weak viewModel] text in
      viewModel?.didInputAmount(text ?? "")
    }
    
    customView.continueButton.configuration.action = { [weak viewModel] in
      viewModel?.didTapContinueButton()
    }
    
    segmentedControl.didChangeSegment = { [weak viewModel] selectedSegmentIndex in
      viewModel?.didSelectSegment(at: selectedSegmentIndex)
    }
  }
  
}
