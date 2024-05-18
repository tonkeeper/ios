import UIKit
import TKUIKit
import TKLocalize

final class StakeViewController: GenericViewViewController<StakeView>, KeyboardObserving {
  
  private let viewModel: StakeViewModel
  
  init(viewModel: StakeViewModel) {
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
    setupViewEvents()
    viewModel.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
    // customView.walletNameTextField.becomeFirstResponder()
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration,
          let keyboardHeight = notification.keyboardSize?.height else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.keyboardHeight = keyboardHeight
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.keyboardHeight = 0
    }
  }
}

private extension StakeViewController {
  func setup() {
    title = TKLocales.Stake.title
    view.backgroundColor = .Background.page
    
    let infoButton = StakeInfoButton()
    infoButton.addTarget(self, action: #selector(didTapInfoButton), for: .touchUpInside)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: infoButton)
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
    
    viewModel.didUpdateContinueButtonIsEnabled = { [weak customView] isEnabled in
      customView?.continueButton.isEnabled = isEnabled
    }
    
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: "Tonstakers".withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      ),
      tagViewModel: .init(
        text: "MAX APY",
        textColor: .Accent.green,
        backgroundColor: .Accent.green.withAlphaComponent(0.44)
      ),
      subtitle: nil,
      description: "APY ≈ 5.01% · 50.01 TON Value".withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
    )
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: leftItemConfiguration,
      rightItemConfiguration: nil
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: .image(
          TKUIListItemImageIconView.Configuration(
            image: .image(.TKUIKit.Icons.Size44.tonstakers),
            tintColor: .Accent.blue,
            backgroundColor: .clear,
            size: CGSize(width: 44, height: 44),
            cornerRadius: .zero
          )
        ),
        alignment: .center
      ),
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .image(
        .init(
          image: .TKUIKit.Icons.Size16.switch,
          tintColor: .Text.tertiary,
          padding: .zero
        )
      )
    )
    
    let stakeConfiguration = StakeListItemView.Configuration(listItemConfiguration: listItemConfiguration)
    
    customView.stakeListItemView.configure(configuration: stakeConfiguration)
  }
  
  func setupViewEvents() {
    customView.balanceView.didTapMax = { [weak viewModel] in
      
    }
    
    customView.stakeListItemView.didTapListItem = { [weak viewModel] in
      viewModel?.didTapToOptions()
    }
    
    customView.balanceView.insufficientLabel.isHidden = false
    
    customView.stakeInputView.didUpdateText = { [weak viewModel] in
      viewModel?.didInputAmount($0 ?? "")
    }
  }
  
  @objc
  func didTapInfoButton() {
    // TODO: Add action
  }
  
}
