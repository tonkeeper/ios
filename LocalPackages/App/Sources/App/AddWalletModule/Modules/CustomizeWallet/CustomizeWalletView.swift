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
  
  let walletNameTextField = CustomizeWalletTextInputField()
  let walletNameTextFieldContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .walletNameTextFieldPadding
    return container
  }()
  
  let colorPickerView = WalletColorPickerView()
  
  let emojiPickerView = WalletEmojiPickerView()
  let emojiPicketContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .emojiPickerViewPadding
    return container
  }()
  
  let continueButton = TKUIActionButton(category: .primary, size: .large)
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
    struct ContinueButton {
      let model: TKUIActionButton.Model
      let action: () -> Void
    }
    let titleDescriptionModel: TKTitleDescriptionView.Model
    let walletNameTextFieldPlaceholder: String
    let walletNameDefaultValue: String
    let colorPickerModel: WalletColorPickerView.Model
    let emojiPicketModel: WalletEmojiPickerView.Model
    let continueButtonModel: ContinueButton?
  }
  
  func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    walletNameTextField.placeholder = model.walletNameTextFieldPlaceholder
    walletNameTextField.text = model.walletNameDefaultValue
    colorPickerView.configure(model: model.colorPickerModel)
    emojiPickerView.configure(model: model.emojiPicketModel)
    if let continueButtonModel = model.continueButtonModel {
      continueButton.configure(model: continueButtonModel.model)
      continueButton.addTapAction(continueButtonModel.action)
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
    
    addSubview(contentStackView)
    addSubview(continueButtonContainer)
    contentStackView.addArrangedSubview(titleDescriptionView)
    contentStackView.addArrangedSubview(walletNameTextFieldContainer)
    contentStackView.addArrangedSubview(colorPickerView)
    contentStackView.addArrangedSubview(emojiPicketContainer)
    
    walletNameTextFieldContainer.setViews([walletNameTextField])
    emojiPicketContainer.setViews([emojiPickerView])
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
