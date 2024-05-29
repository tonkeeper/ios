import UIKit
import TKUIKit

final class BuySellAmountViewController: GenericViewViewController<BuySellAmountView> {
  private let viewModel: BuySellAmountViewModel
  
  private let amountInputViewController = BuyAmountInputViewController()
  
  init(viewModel: BuySellAmountViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Amount"
    view.backgroundColor = .Background.page
    
    setup()
    setupBindings()
    setupViewEventsBinding()
    viewModel.viewDidLoad()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    viewModel.viewDidAppear()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    viewModel.viewWillDisappear()
  }
}

private extension BuySellAmountViewController {
  func setup() {
    addChild(amountInputViewController)
    customView.embedAmountInputView(amountInputViewController.view)
    amountInputViewController.didMove(toParent: self)
    
    navigationItem.titleView = customView.titleView
    setupRightCloseButton { [weak self] in
      self?.dismiss(animated: true)
    }
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: customView.currencyButton)
  }
  
  func setupBindings() {
    viewModel.didUpdateConvertedValue = { [weak self] value in
      self?.amountInputViewController.convertedValue = value
    }
    
    viewModel.didUpdateInputValue = { [weak self] value in
      self?.amountInputViewController.inputValue = value ?? ""
    }
    
    viewModel.didUpdateInputSymbol = { [weak self] symbol in
      self?.amountInputViewController.inputSymbol = symbol ?? ""
    }
    
    viewModel.didUpdateMaximumFractionDigits = { [weak self] fractionDigits in
      self?.amountInputViewController.maximumFractionDigits = fractionDigits
    }
    
    customView.currencyButton.configuration.action = { [weak self] in
      guard let self else {return}
      viewModel.openCurrencyPicker()
    }
    
    viewModel.didUpdateCurrency = { [weak self] currency in
      guard let self else {return}
      customView.currencyButton.configuration.content.title = .plainString(currency.code)
    }
  }
  
  func setupViewEventsBinding() {
    amountInputViewController.didUpdateText = { [weak viewModel] text in
      viewModel?.didEditInput(text)
    }
    
    amountInputViewController.didToggle = { [weak viewModel] in
      viewModel?.toggleInputMode()
    }
  }
}
