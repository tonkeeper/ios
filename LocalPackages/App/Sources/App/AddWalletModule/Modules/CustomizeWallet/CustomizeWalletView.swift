import UIKit
import TKUIKit

final class CustomizeWalletView: UIView, ConfigurableView {
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  let titleDescriptionView: TKTitleDescriptionView = {
    let view = TKTitleDescriptionView(size: .big)
    view.padding = .titleDescriptionPadding
    return view
  }()
  
  lazy var walletNameTextField: TKTextField = {
    let textFieldInputView = TKTextFieldInputView(
      textInputControl: TKTextInputTextFieldControl()
    )
    textFieldInputView.clearButtonMode = .never
    return TKTextField(
      textFieldInputView: textFieldInputView
    )
  }()
  let walletNameTextFieldContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .walletNameTextFieldPadding
    return container
  }()
  
  let badgeView = WalletColorIconBadgeView()
  
  let colorPickerView = WalletColorPickerView()
  
  let iconPickerView = WalletIconPickerView()
  let iconPickerContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .emojiPickerViewPadding
    return container
  }()
  
  let continueButton = TKButton()
  let continueButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.backgroundView = TKGradientView(color: .Background.page, direction: .bottomToTop)
    container.padding = .continueButtonPadding
    return container
  }()
  
  private lazy var continueButtonContainerBottomConstraint: NSLayoutConstraint = {
    return continueButtonContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
  }()
  
  var keyboardHeight: CGFloat = 0 {
    didSet {
      let continueButtonContainerYTranslation = min(0, -keyboardHeight + safeAreaInsets.bottom)
      continueButtonContainer.transform = CGAffineTransform(translationX: 0, y: continueButtonContainerYTranslation)
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  struct Model {
    let titleDescriptionModel: TKTitleDescriptionView.Model
    let continueButtonConfiguration: TKButton.Configuration?
    let walletNameTextFieldPlaceholder: String
    let walletNameDefaultValue: String
    let colorPickerModel: WalletColorPickerView.Model
    let iconPickerModel: WalletIconPickerView.Model
  }
  
  func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    walletNameTextField.placeholder = model.walletNameTextFieldPlaceholder
    walletNameTextField.text = model.walletNameDefaultValue
    colorPickerView.configure(model: model.colorPickerModel)
    iconPickerView.configure(model: model.iconPickerModel)
    if let continueButtonConfiguration = model.continueButtonConfiguration {
      continueButton.configuration = continueButtonConfiguration
      continueButton.isHidden = false
    } else {
      continueButton.isHidden = true
    }
  }
}

private extension CustomizeWalletView {
  func setup() {
    backgroundColor = .Background.page
    
    titleDescriptionView.setContentHuggingPriority(.required, for: .vertical)
    
    colorPickerView.collectionView.contentInset = .colorPickerViewContentInsets
    
    badgeView.padding = UIEdgeInsets(
      top: 8,
      left: 8,
      bottom: 8,
      right: 8
    )
    
    addSubview(contentStackView)
    addSubview(continueButtonContainer)
    contentStackView.addArrangedSubview(titleDescriptionView)
    contentStackView.addArrangedSubview(walletNameTextFieldContainer)
    contentStackView.addArrangedSubview(colorPickerView)
    contentStackView.addArrangedSubview(iconPickerContainer)
    
    
    walletNameTextField.rightItems = [TKTextField.RightItem(
      view: badgeView,
      mode: .always
    )]
    
    walletNameTextFieldContainer.setViews([walletNameTextField])
    iconPickerContainer.setViews([iconPickerView])
    continueButtonContainer.setViews([continueButton])
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    continueButtonContainer.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentStackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: leftAnchor),
      contentStackView.bottomAnchor.constraint(equalTo: continueButtonContainer.topAnchor),
      contentStackView.rightAnchor.constraint(equalTo: rightAnchor),
      
      continueButtonContainerBottomConstraint,
      continueButtonContainer.leftAnchor.constraint(equalTo: leftAnchor),
      continueButtonContainer.rightAnchor.constraint(equalTo: rightAnchor),
    ])
  }
}

private extension NSDirectionalEdgeInsets {
  static let titleDescriptionPadding = NSDirectionalEdgeInsets(
    top: 24,
    leading: 32,
    bottom: 16,
    trailing: 32
  )
}

private extension UIEdgeInsets {
  static let walletNameTextFieldPadding = UIEdgeInsets(
    top: 16,
    left: 32,
    bottom: 16,
    right: 32
  )
  
  static let colorPickerViewContentInsets = UIEdgeInsets(
    top: 0,
    left: 32,
    bottom: 0,
    right: 32
  )
  
  static let emojiPickerViewPadding = UIEdgeInsets(
    top: 0,
    left: 27,
    bottom: 0,
    right: 27
  )
  
  static let continueButtonPadding = UIEdgeInsets(
    top: 16,
    left: 32,
    bottom: 32,
    right: 32
  )
}
