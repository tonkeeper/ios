import UIKit
import TKUIKit

final class SendAmountViewController: GenericViewViewController<SendAmountView> {
  private let viewModel: SendAmountViewModel
  
  private let amountInputViewController = AmountInputViewController()
  
  init(viewModel: SendAmountViewModel) {
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

private extension SendAmountViewController {
  func setup() {
    addChild(amountInputViewController)
    customView.embedAmountInputView(amountInputViewController.view)
    amountInputViewController.didMove(toParent: self)
    
    customView.maxButton.configure(model: TKButton.Model(title: "MAX"))
    customView.maxButton.addAction(UIAction(handler: { [weak customView, weak viewModel] _ in
      customView?.maxButton.isSelected.toggle()
      viewModel?.toggleMax()
    }), for: .touchUpInside)
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
    
    viewModel.didUpdateIsTokenPickerAvailable = { [weak self] in
      self?.amountInputViewController.isTokenPickerAvailable = $0
    }
    
    viewModel.didUpdateRemaining = { [weak self] value in
      self?.customView.remainingLabel.attributedText = value
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
