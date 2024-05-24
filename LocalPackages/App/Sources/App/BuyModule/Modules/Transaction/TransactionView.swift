import UIKit
import TKUIKit
import SnapKit

final class TransactionView: UIView, ConfigurableView {
  
  struct Model {
    public enum Image {
      case image(UIImage)
      case asyncImage(ImageDownloadTask)
    }
    // Const???
    public let image: Image
    public let providerName: String
    public let providerDescription: String?
    public let rate: String
    public let toPlaceholder: String
    public let fromPlaceholder: String
    
    // To Model
    public let fromCurrency: String
    public let toCurrency: String
    
    public let toAmountString: String
    public let fromAmountString: String
    
    public let isContinueButtonEnabled: Bool
    public let isMinAmountShown: Bool
    public let minAmountDisclaimer: String
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
  
  lazy var insufficientFundsLabel: UILabel = {
    let label = UILabel()
    label.font = .insufficientFundsFont
    label.textColor = .Accent.red
    return label
  }()
  
  lazy var fromTextField: TKTextField = {
    let textFieldInputView = TKTextFieldInputView(
      textInputControl: TKTextInputTextFieldControl()
    )
    textFieldInputView.clearButtonMode = .never
    return TKTextField(
      textFieldInputView: textFieldInputView
    )
  }()
  
  lazy var toTextField: TKTextField = {
    let textFieldInputView = TKTextFieldInputView(
      textInputControl: TKTextInputTextFieldControl()
    )
    textFieldInputView.clearButtonMode = .never
    return TKTextField(
      textFieldInputView: textFieldInputView
    )
  }()
  
    
  let continueButton = TKButton()
  let continueButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.backgroundView = TKGradientView(color: .Background.page, direction: .bottomToTop)
    container.padding = .continueButtonPadding
    return container
  }()
  
  private var continueButtonContainerSafeAreaBottomConstraint: Constraint?
  private var continueButtonContainerBottomConstraint: Constraint?
  
  var keyboardHeight: CGFloat = 0 {
    didSet {
      if keyboardHeight.isZero {
        continueButtonContainerBottomConstraint?.isActive = false
        continueButtonContainerSafeAreaBottomConstraint?.isActive = true
      } else {
        continueButtonContainerSafeAreaBottomConstraint?.isActive = false
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
    fromTextField.placeholder = model.fromPlaceholder
    toTextField.placeholder = model.toPlaceholder
    
    fromTextField.text = model.fromAmountString
    toTextField.text = model.toAmountString
    
    continueButton.configuration.isEnabled = model.isContinueButtonEnabled
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
    addSubview(fromTextField)
    addSubview(toTextField)
    addSubview(rateLabel)
    addSubview(insufficientFundsLabel)
    
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
    
    fromTextField.snp.makeConstraints { make in
      make.top.equalTo(descriptionLabel.snp.bottom).offset(32)
      make.leading.equalToSuperview().offset(16)
      make.trailing.equalToSuperview().offset(-16)
    }
    
    toTextField.snp.makeConstraints { make in
      make.top.equalTo(fromTextField.snp.bottom).offset(16)
      make.leading.equalToSuperview().offset(16)
      make.trailing.equalToSuperview().offset(-16)
    }
    
    rateLabel.snp.makeConstraints { make in
      make.top.equalTo(toTextField.snp.bottom).offset(12)
      make.leading.equalToSuperview().offset(32)
    }

    continueButtonContainer.snp.makeConstraints { make in
      make.leading.equalToSuperview()
      make.trailing.equalToSuperview()
      self.continueButtonContainerBottomConstraint = make.bottom.equalTo(self.safeAreaLayoutGuide.snp.bottom).constraint
      self.continueButtonContainerBottomConstraint = make.bottom.equalTo(self.snp.bottom).constraint
    }
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
