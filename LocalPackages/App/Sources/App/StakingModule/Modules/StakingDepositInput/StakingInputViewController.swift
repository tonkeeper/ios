import UIKit
import TKUIKit

final class StakingInputViewController: GenericViewViewController<StakingInputView>, KeyboardObserving {
  private let viewModel: StakingInputViewModel
  private let detailsViewController: UIViewController
  private let amountInputViewController: UIViewController
  
  init(viewModel: StakingInputViewModel,
       amountInputViewController: UIViewController,
       detailsViewController: UIViewController) {
    self.viewModel = viewModel
    self.amountInputViewController = amountInputViewController
    self.detailsViewController = detailsViewController
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
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
    amountInputViewController.becomeFirstResponder()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    customView.navigationBar.layoutIfNeeded()
    customView.scrollView.contentInset.top = customView.navigationBar.bounds.height
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration,
    let keyboardHeight = notification.keyboardSize?.height else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.keyboardHeight = keyboardHeight + 16
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

private extension StakingInputViewController {

  func setup() {
    setupNavigationBar()
    
    customView.scrollView.contentInsetAdjustmentBehavior = .never
    
    addChild(amountInputViewController)
    customView.setAmountInputView(amountInputViewController.view)
    amountInputViewController.didMove(toParent: self)
    
    addChild(detailsViewController)
    customView.setDetailsView(detailsViewController.view)
    detailsViewController.didMove(toParent: self)
  
    customView.continueButton.configuration.action = { [weak viewModel] in
      viewModel?.didTapContinue()
    }
  }
  
  private func setupNavigationBar() {
    guard let navigationController,
          !navigationController.viewControllers.isEmpty else {
      return
    }
    
    customView.navigationBar.leftViews = [
      TKUINavigationBar.createButton(
        icon: .TKUIKit.Icons.Size16.informationCircle,
        action: { [weak self] _ in
          self?.viewModel.didTapStakingInfoButton()
        }
      )
    ]
    
    customView.navigationBar.rightViews = [
      TKUINavigationBar.createCloseButton { [weak self] in
        self?.viewModel.didTapCloseButton()
      }
    ]
  }
  
  func setupBindings() {
    viewModel.didUpdateTitle = { [weak self] title in
      self?.customView.titleView.configure(
        model: TKUINavigationBarTitleView.Model(
          title: title.withTextStyle(
            .h3,
            color: .Text.primary,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
          )
        )
      )
    }

    viewModel.didUpdateButton = { [weak self] title, isEnable in
      self?.customView.continueButton.configuration.content.title = .plainString(title)
      self?.customView.continueButton.isEnabled = isEnable
    }
  }
}
