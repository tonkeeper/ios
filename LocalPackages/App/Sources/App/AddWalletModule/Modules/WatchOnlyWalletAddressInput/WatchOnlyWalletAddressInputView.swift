import UIKit
import TKUIKit
import SnapKit

final class WatchOnlyWalletAddressInputView: UIView, ConfigurableView {
  let scrollView = UIScrollView()
  
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
  
  lazy var textField: TKTextField = {
    let textFieldInputView = TKTextFieldInputView(
      textInputControl: TKTextInputTextViewControl()
    )
    return TKTextField(
      textFieldInputView: textFieldInputView
    )
  }()
  let textFieldContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .walletNameTextFieldPadding
    return container
  }()
  
  let continueButton = TKButton()
  let continueButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.backgroundView = TKGradientView(color: .Background.page, direction: .bottomToTop)
    container.padding = .continueButtonPadding
    return container
  }()

  var keyboardHeight: CGFloat = 0 {
    didSet {
      let continueButtonContainerYTranslation = min(0, -keyboardHeight + safeAreaInsets.bottom)
      continueButtonContainer.transform = CGAffineTransform(translationX: 0, y: continueButtonContainerYTranslation)
      scrollView.contentInset.bottom = keyboardHeight
    }
  }
  
  private var continueButtonContainerBottomConstraint: Constraint?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  struct Model {
    let titleDescriptionModel: TKTitleDescriptionView.Model
    let placeholder: String
  }
  
  func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    
    textField.placeholder = model.placeholder
  }
}

private extension WatchOnlyWalletAddressInputView {
  func setup() {
    backgroundColor = .Background.page
    
    titleDescriptionView.setContentHuggingPriority(.required, for: .vertical)
    
    addSubview(scrollView)
    scrollView.addSubview(contentStackView)
    addSubview(continueButtonContainer)
    contentStackView.addArrangedSubview(titleDescriptionView)
    contentStackView.addArrangedSubview(textFieldContainer)
    
    textFieldContainer.setViews([textField])
    continueButtonContainer.setViews([continueButton])
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
      make.bottom.equalTo(continueButtonContainer.snp.top)
    }
    
    contentStackView.snp.makeConstraints { make in
      make.top.equalTo(scrollView)
      make.left.right.equalTo(scrollView)
      make.bottom.equalTo(scrollView)
      make.width.equalTo(self)
    }
    
    continueButtonContainer.snp.makeConstraints { make in
      continueButtonContainerBottomConstraint = make.bottom.equalTo(safeAreaLayoutGuide).constraint
      make.left.right.equalTo(self)
    }
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
