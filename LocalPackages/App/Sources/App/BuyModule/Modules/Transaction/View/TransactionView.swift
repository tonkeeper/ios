import UIKit
import TKUIKit
import SnapKit

final class TransactionView: UIView, ConfigurableView {
  
  struct Model {
    public struct InputField {
      public let placeholder: String
      public let currency: String
      public let amount: String
      public let isValid: Bool
    }
    
    public enum Image {
      case image(UIImage)
      case asyncImage(ImageDownloadTask)
    }
    
    public let image: Image
    public let providerName: String
    public let providerDescription: String?
    public let rate: String
    public let payField: InputField
    public let getField: InputField
    
    public let isContinueButtonEnabled: Bool
    public let isErrorShown: Bool
    public let errorMessage: String?
    
    public let serviceDescription: NSAttributedString?
  }
  
  let logoImageView = UIImageView()
  
  lazy var nameLabel: UILabel = {
    let label = UILabel()
    label.font = .nameFont
    label.textColor = .Text.primary
    label.textAlignment = .center
    return label
  }()
  
  lazy var descriptionLabel: UILabel = {
    let label = UILabel()
    label.font = .descriptionFont
    label.textColor = .Text.secondary
    label.textAlignment = .center
    return label
  }()
  
  lazy var rateLabel: UILabel = {
    let label = UILabel()
    label.font = .rateFont
    label.textColor = .Text.tertiary
    label.textAlignment = .left
    return label
  }()
  
  lazy var errorMessageLabel: UILabel = {
    let label = UILabel()
    label.font = .insufficientFundsFont
    label.textColor = .Accent.red
    return label
  }()
  
  lazy var payCurrencyLabel: UILabel = {
    let label = UILabel()
    label.font = .descriptionFont
    label.textColor = .Text.secondary
    return label
  }()
  
  lazy var getCurrencyLabel: UILabel = {
    let label = UILabel()
    label.font = .descriptionFont
    label.textColor = .Text.secondary
    return label
  }()
  
  lazy var payTextField: TKTextField = {
    let textInputControl = CurrencyPlaceholderTextFieldControl()
    textInputControl.rightView = payCurrencyLabel
    textInputControl.rightViewMode = .always
    textInputControl.keyboardAppearance = .dark
    textInputControl.keyboardType = .decimalPad
    
    let textFieldInputView = TKTextFieldInputView(
      textInputControl: textInputControl
    )
    textFieldInputView.clearButtonMode = .never
    let textField = TKTextField(
      textFieldInputView: textFieldInputView
    )
    return textField
  }()
  
  lazy var getTextField: TKTextField = {
    let textInputControl = CurrencyPlaceholderTextFieldControl()
    textInputControl.rightView = getCurrencyLabel
    textInputControl.rightViewMode = .always
    textInputControl.keyboardAppearance = .dark
    textInputControl.keyboardType = .decimalPad
    
    let textFieldInputView = TKTextFieldInputView(
      textInputControl: textInputControl
    )
    textFieldInputView.clearButtonMode = .never
    let textField = TKTextField(
      textFieldInputView: textFieldInputView
    )
    return textField
  }()
  
  lazy var descriptionTextView: UITextView = {
    let textView = UITextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.dataDetectorTypes = .link
    textView.textAlignment = .center
    textView.isScrollEnabled = false
    textView.backgroundColor = .clear
    textView.linkTextAttributes = [
      .font: TKTextStyle.body2.font,
      .foregroundColor: UIColor.Text.secondary,
    ]
    return textView
  }()
  
    
  let continueButton = TKButton()
  let continueButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.backgroundView = TKGradientView(color: .Background.page, direction: .bottomToTop)
    container.padding = .continueButtonPadding
    return container
  }()
  
  private var continueButtonContainerToTextViewBottomConstraint: Constraint?
  private var continueButtonContainerBottomConstraint: Constraint?
  
  var keyboardHeight: CGFloat = 0 {
    didSet {
      if keyboardHeight.isZero {
        continueButtonContainerBottomConstraint?.isActive = false
        continueButtonContainerToTextViewBottomConstraint?.isActive = true
      } else {
        continueButtonContainerToTextViewBottomConstraint?.isActive = false
        continueButtonContainerBottomConstraint?.update(inset: keyboardHeight)
        continueButtonContainerBottomConstraint?.isActive = true
      }
    }
  }
  
  func configure(model: Model) {
    switch model.image {
    case .image(let uiImage):
      logoImageView.image = uiImage
    case .asyncImage(let imageDownloadTask):
      imageDownloadTask.start(
        imageView: logoImageView,
        size: CGSize(width: 72, height: 72),
        cornerRadius: 20
      )
    }
        
    nameLabel.text = model.providerName
    descriptionLabel.text = model.providerDescription
    rateLabel.text = model.rate
    
    payTextField.placeholder = model.payField.placeholder
    payTextField.text = model.payField.amount
    payTextField.isValid = model.payField.isValid
    
    getTextField.placeholder = model.getField.placeholder
    getTextField.text = model.getField.amount
    getTextField.isValid = model.getField.isValid
    
    payCurrencyLabel.text = model.payField.currency
    getCurrencyLabel.text = model.getField.currency
    
    continueButton.configuration.isEnabled = model.isContinueButtonEnabled
    
    errorMessageLabel.isHidden = !model.isErrorShown
    errorMessageLabel.text = model.errorMessage
    
    descriptionTextView.attributedText = model.serviceDescription
  }
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Private

private extension TransactionView {
  func setup() {
    backgroundColor = .Background.page
    addSubview(continueButtonContainer)
    continueButtonContainer.setViews([continueButton])
    
    addSubview(logoImageView)
    addSubview(nameLabel)
    addSubview(descriptionLabel)
    addSubview(payTextField)
    addSubview(getTextField)
    addSubview(rateLabel)
    addSubview(errorMessageLabel)
    addSubview(descriptionTextView)
        
    logoImageView.snp.makeConstraints { make in
      make.top.equalTo(self.safeAreaLayoutGuide.snp.top)
      make.centerX.equalToSuperview()
      make.width.equalTo(72)
      make.height.equalTo(72)
    }
    
    nameLabel.snp.makeConstraints { make in
      make.top.equalTo(logoImageView.snp.bottom).offset(20)
      make.leading.equalToSuperview().offset(32)
      make.trailing.equalToSuperview().offset(-32)
    }
    
    descriptionLabel.snp.makeConstraints { make in
      make.top.equalTo(nameLabel.snp.bottom).offset(4)
      make.leading.equalToSuperview().offset(32)
      make.trailing.equalToSuperview().offset(-32)
    }
    
    payTextField.snp.makeConstraints { make in
      make.top.equalTo(descriptionLabel.snp.bottom).offset(32)
      make.leading.equalToSuperview().offset(16)
      make.trailing.equalToSuperview().offset(-16)
    }
    
    getTextField.snp.makeConstraints { make in
      make.top.equalTo(payTextField.snp.bottom).offset(16)
      make.leading.equalToSuperview().offset(16)
      make.trailing.equalToSuperview().offset(-16)
    }
    
    rateLabel.snp.makeConstraints { make in
      make.top.equalTo(getTextField.snp.bottom).offset(12)
      make.leading.equalToSuperview().offset(32)
    }
    
    errorMessageLabel.snp.makeConstraints { make in
      make.top.equalTo(getTextField.snp.bottom).offset(12)
      make.trailing.equalToSuperview().offset(-32)
    }
    
    descriptionTextView.snp.makeConstraints { make in
      make.leading.equalToSuperview().offset(32)
      make.trailing.equalToSuperview().offset(-32)
      make.bottom.equalTo(self.safeAreaLayoutGuide.snp.bottom).offset(-16)
    }

    continueButtonContainer.snp.makeConstraints { make in
      make.leading.equalToSuperview()
      make.trailing.equalToSuperview()
      self.continueButtonContainerBottomConstraint = make.bottom.equalTo(self.snp.bottom).constraint
      self.continueButtonContainerToTextViewBottomConstraint = make.bottom.equalTo(self.descriptionTextView.snp.top).constraint
    }
    
    continueButtonContainerBottomConstraint?.isActive = false
    continueButtonContainerToTextViewBottomConstraint?.isActive = true
  }
}

private extension UIEdgeInsets {
  
  static let continueButtonPadding = UIEdgeInsets(
    top: 16,
    left: 16,
    bottom: 16,
    right: 16
  )
}

private extension UIFont {
  static var nameFont: UIFont = TKTextStyle.h2.font
  static var descriptionFont: UIFont = TKTextStyle.body1.font
  static var rateFont: UIFont = TKTextStyle.body2.font
  static var insufficientFundsFont: UIFont = TKTextStyle.body2.font
}