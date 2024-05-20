import UIKit
import TKUIKit

final class SwapViewController: ModalViewController<SwapView, ModalNavigationBarView>, KeyboardObserving {
  
  private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(resignGestureAction))
    gestureRecognizer.cancelsTouchesInView = false
    return gestureRecognizer
  }()
  
  // MARK: - Dependencies
  
  private let viewModel: SwapViewModel
  
  // MARK: - Init
  
  init(viewModel: SwapViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
  
  // MARK: - View Life cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBindings()
    setupGestures()
    setupViewEvents()
    
    viewModel.viewDidLoad()
  }
  
  override func setupNavigationBarView() {
    super.setupNavigationBarView()
    
    customView.scrollView.contentInset.top = ModalNavigationBarView.defaultHeight
    
    customNavigationBarView.setupLeftBarItem(
      configuration: ModalNavigationBarView.BarItemConfiguration(
        view: customView.swapSettingsButton,
        contentAlignment: .center
      )
    )
    
    customNavigationBarView.setupCenterBarItem(
      configuration: ModalNavigationBarView.BarItemConfiguration(
        view: customView.titleView
      )
    )
  }
}

// MARK: - Setup

private extension SwapViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.backgroundColor = .Background.page
    
    customView.swapSendContainerView.textField.delegate = viewModel.amountInpuTextFieldFormatter
    customView.swapRecieveContainerView.textField.delegate = viewModel.amountInpuTextFieldFormatter
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let customView = self?.customView else { return }
      
      customView.titleView.configure(model: .init(title: model.title))
      customView.swapSettingsButton.configuration.content.icon = .TKUIKit.Icons.Size16.sliders
      customView.swapButton.configuration.action = model.swapButton.action
    }
    
    viewModel.didUpdateStateModel = { [weak self] stateModel in
      guard let customView = self?.customView else { return }
      
      customView.swapSendContainerView.textField.textFieldState = stateModel.sendTextFieldState
      
      customView.continueButton.configuration.content.title = .plainString(stateModel.actionButton.title)
      customView.continueButton.configuration.isEnabled = stateModel.actionButton.isEnabled
      customView.continueButton.configuration.showsLoader = stateModel.actionButton.isActivity
      customView.continueButton.configuration.action = stateModel.actionButton.action
      customView.continueButton.configuration.backgroundColors = [
        .normal : stateModel.actionButton.backgroundColor,
        .highlighted : stateModel.actionButton.backgroundColorHighlighted,
        .disabled : stateModel.actionButton.backgroundColor
      ]
    }
    
    viewModel.didUpdateAmountSend = { [weak self] amountSend in
      self?.customView.swapSendContainerView.textField.text = amountSend
    }
    
    viewModel.didUpdateAmountRecieve = { [weak self] amountRecieve in
      self?.customView.swapRecieveContainerView.textField.text = amountRecieve
    }
    
    viewModel.didUpdateSendTokenBalance = { [weak self] balanceTitle in
      self?.customView.swapSendContainerView.inputContainerView.setBalanceTitle(balanceTitle)
    }
    
    viewModel.didUpdateRecieveTokenBalance = { [weak self] balanceTitle in
      self?.customView.swapRecieveContainerView.inputContainerView.setBalanceTitle(balanceTitle)
    }
    
    viewModel.didUpdateSwapSendContainer = { [weak self] model in
      self?.customView.swapSendContainerView.configure(model: model)
    }
    
    viewModel.didUpdateSwapRecieveContainer = { [weak self] model in
      self?.customView.swapRecieveContainerView.configure(model: model)
    }
  }
  
  func setupGestures() {
    customView.addGestureRecognizer(tapGestureRecognizer)
  }
  
  func setupViewEvents() {
    customView.swapSendContainerView.textField.didUpdateText = { [weak self] text in
      self?.viewModel.didInputAmountSend(text)
    }
    
    customView.swapRecieveContainerView.textField.didUpdateText = { [weak self] text in
      self?.viewModel.didInputAmountRecieve(text)
    }
  }
  
  @objc func resignGestureAction(sender: UITapGestureRecognizer) {
    customView.swapSendContainerView.textField.resignFirstResponder()
    customView.swapRecieveContainerView.textField.resignFirstResponder()
  }
}
