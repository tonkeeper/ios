import UIKit
import TKUIKit

final class BuySellDetailsViewController: ModalViewController<BuySellDetailsView, ModalNavigationBarView>, KeyboardObserving {
  
  private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(resignGestureAction))
    gestureRecognizer.cancelsTouchesInView = false
    return gestureRecognizer
  }()
  
  // MARK: - Dependencies
  
  private let viewModel: BuySellDetailsViewModel
  
  // MARK: - Init
  
  init(viewModel: BuySellDetailsViewModel) {
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
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    registerForKeyboardEvents()
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    unregisterFromKeyboardEvents()
  }
  
  override func setupNavigationBarView() {
    super.setupNavigationBarView()
    
    customView.scrollView.contentInset.top = ModalNavigationBarView.defaultHeight
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration,
          let keyboardHeight = notification.keyboardSize?.height
    else {
      return
    }
    
    let contentInsetBottom = keyboardHeight + customView.continueButton.bounds.height
    let continueButtonTranslatedY = -keyboardHeight + view.safeAreaInsets.bottom + .continueButtonBottomOffset
    
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.scrollView.contentInset.bottom = contentInsetBottom
      self.customView.continueButton.transform = CGAffineTransform(translationX: 0, y: continueButtonTranslatedY)
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.scrollView.contentInset.bottom = 0
      self.customView.continueButton.transform = .identity
    }
  }
}

// MARK: - Setup

private extension BuySellDetailsViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.backgroundColor = .Background.page
    
    customView.payAmountInputControl.formatterDelegate = viewModel.payAmountTextFieldFormatter
    customView.getAmountInputControl.formatterDelegate = viewModel.getAmountTextFieldFormatter
    
    customView.payAmountInputView.didInputText("0", animateTextActions: false)
    customView.getAmountInputView.didInputText("0", animateTextActions: false)
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let customView = self?.customView, let self else { return }
      
      customView.serviceInfoContainerView.configure(
        configuration: .init(
          image: self.mapIconImageConfiguration(model.icon),
          title: model.title.withTextStyle(.h2, color: .Text.primary),
          subtitle: model.subtitle.withTextStyle(.body1, color: .Text.secondary)
        )
      )
      
      customView.payAmountTextField.placeholder = model.textFieldPay.placeholder
      customView.getAmountTextField.placeholder = model.textFieldGet.placeholder
      
      customView.setPayAmountCursorLabel(title: model.textFieldPay.currencyCode)
      customView.setGetAmountCursorLabel(title: model.textFieldGet.currencyCode)
      
      customView.convertedRateContainer.configuration.description = model.convertedRate.withTextStyle(.body2, color: .Text.tertiary)
      
      customView.continueButton.configuration.content = TKButton.Configuration.Content(title: .plainString(model.continueButton.title))
      customView.continueButton.configuration.isEnabled = model.continueButton.isEnabled
      customView.continueButton.configuration.showsLoader = model.continueButton.isActivity
      customView.continueButton.configuration.action = model.continueButton.action
      
      customView.serviceProvidedLabel.attributedText = model.infoContainer.description.withTextStyle(.label2, color: .Text.tertiary)
      
      customView.infoButtonsContainer.configure(
        configuration: .init(
          leftButton: self.mapInfoContainerButtonConfiguration(model.infoContainer.leftButton),
          rightButton: self.mapInfoContainerButtonConfiguration(model.infoContainer.rightButton)
        )
      )
    }
    
    viewModel.didUpdateAmountPay = { [weak customView] text in
      customView?.payAmountTextField.text = text
    }
    
    viewModel.didUpdateAmountGet = { [weak customView] text in
      customView?.getAmountTextField.text = text
    }
    
    viewModel.didUpdateConvertedRate = { [weak customView] convertedRateText in
      customView?.convertedRateContainer.configuration.description = convertedRateText.withTextStyle(.label2, color: .Text.tertiary)
    }
  }
  
  func setupGestures() {
    customView.contentStackView.addGestureRecognizer(tapGestureRecognizer)
  }
  
  func setupViewEvents() {
    customView.payAmountTextField.didUpdateText = { [weak self] text in
      self?.viewModel.didInputAmountPay(text)
    }
    
    customView.getAmountTextField.didUpdateText = { [weak self] text in
      self?.viewModel.didInputAmountGet(text)
    }
  }
  
  func mapIconImageConfiguration(_ icon: BuySellDetailsModel.Icon) -> ServiceInfoContainerView.Configuration.Image {
    switch icon {
    case .image(let image):
      return .image(image)
    case .asyncImage(let imageDownloadTask):
      return .asyncImage(imageDownloadTask)
    }
  }
  
  func mapInfoContainerButtonConfiguration(
    _ button: BuySellDetailsModel.InfoContainer.InfoButton?
  ) -> InfoButtonsContainerView.Configuration.Button? {
    guard let button else { return nil }
    let title = button.title.withTextStyle(.body2, color: .Text.secondary)
    return .init(title: title, action: button.action)
  }
  
  @objc func resignGestureAction(sender: UITapGestureRecognizer) {
    let touchLocation = sender.location(in: customView.contentStackView)
    let isTapInPayTextField = customView.payAmountTextField.frame.contains(touchLocation)
    let isTapInGetTextField = customView.getAmountTextField.frame.contains(touchLocation)
    let isTapInTextFields = isTapInPayTextField || isTapInGetTextField
    
    guard !isTapInTextFields else { return }
    
    customView.payAmountTextField.resignFirstResponder()
    customView.getAmountTextField.resignFirstResponder()
  }
}

private extension CGFloat {
  static let continueButtonBottomOffset: CGFloat = 56
}
