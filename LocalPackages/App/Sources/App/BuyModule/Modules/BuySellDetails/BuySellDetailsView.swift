import UIKit
import TKUIKit
import SnapKit
import TKCore

final class BuySellDetailsView: UIView, ConfigurableView {
  
  // MARK: - Views
  
  let scrollView = TKUIScrollView()
  
  let serviceInfoContainerView = ServiceInfoContainerView()
  
  let payAmountInputControl: TKTextInputTextViewControl = .makeAmountInputControl()
  lazy var payAmountInputView: TKTextFieldInputView = .makeAmountInputView(inputControl: payAmountInputControl)
  lazy var payAmountTextField = TKTextField(textFieldInputView: payAmountInputView)

  let getAmountInputControl: TKTextInputTextViewControl = .makeAmountInputControl()
  lazy var getAmountInputView: TKTextFieldInputView = .makeAmountInputView(inputControl: getAmountInputControl)
  lazy var getAmountTextField = TKTextField(textFieldInputView: getAmountInputView)
  
  let rateContainerView = ListDescriptionContainerView()
  
  let serviceProvidedLabel = UILabel()
  let infoButtonsContainer = InfoButtonsContainerView()
  
  let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 0
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = .contentStackViewPadding
    return stackView
  }()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    struct TextField {
      let placeholder: String
      let currencyCode: String
    }
    
    struct Button {
      let title: String
      let isEnabled: Bool
      let isActivity: Bool
      let action: (() -> Void)
    }
    
    let serviceInfo: ServiceInfoContainerView.Model
    let textFieldPay: TextField
    let textFieldGet: TextField
    let rateContainer: ListDescriptionContainerView.Model
    let serviceProvidedTitle: NSAttributedString
    let infoButtonsContainer: InfoButtonsContainerView.Model
    let continueButton: Button
  }
  
  func configure(model: Model) {
    serviceInfoContainerView.configure(model: model.serviceInfo)
    rateContainerView.configure(model: model.rateContainer)
    infoButtonsContainer.configure(model: model.infoButtonsContainer)
    
    payAmountTextField.placeholder = model.textFieldPay.placeholder
    getAmountTextField.placeholder = model.textFieldGet.placeholder
    
    setPayAmountCursorLabel(title: model.textFieldPay.currencyCode)
    setGetAmountCursorLabel(title: model.textFieldGet.currencyCode)
    
    serviceProvidedLabel.attributedText = model.serviceProvidedTitle
    
    continueButton.configuration.content.title = .plainString(model.continueButton.title)
    continueButton.configuration.isEnabled = model.continueButton.isEnabled
    continueButton.configuration.showsLoader = model.continueButton.isActivity
    continueButton.configuration.action = model.continueButton.action
  }
}

// MARK: - Setup

private extension BuySellDetailsView {
  func setup() {
    addSubview(scrollView)
    scrollView.addSubview(contentStackView)
    
    contentStackView.addArrangedSubview(serviceInfoContainerView)
    contentStackView.addArrangedSubview(payAmountTextField)
    contentStackView.setCustomSpacing(.contentVerticalPadding, after: payAmountTextField)
    contentStackView.addArrangedSubview(getAmountTextField)
    contentStackView.addArrangedSubview(rateContainerView)
    
    addSubview(continueButton)
    addSubview(serviceProvidedLabel)
    addSubview(infoButtonsContainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    
    contentStackView.snp.makeConstraints { make in
      make.top.equalTo(scrollView)
      make.left.right.bottom.equalTo(scrollView).priority(.high)
      make.width.equalTo(scrollView)
    }
    
    continueButton.snp.makeConstraints { make in
      make.bottom.equalTo(serviceProvidedLabel.snp.top).offset(-CGFloat.contentHorizontalPadding)
      make.leading.equalTo(self).offset(CGFloat.contentHorizontalPadding)
      make.trailing.equalTo(self).inset(CGFloat.contentHorizontalPadding)
    }
    
    serviceProvidedLabel.snp.makeConstraints { make in
      make.bottom.equalTo(infoButtonsContainer.snp.top)
      make.centerX.equalTo(self)
      make.height.equalTo(CGFloat.infoItemHeight)
    }
    
    infoButtonsContainer.snp.makeConstraints { make in
      make.bottom.equalTo(self.safeAreaLayoutGuide).inset(CGFloat.contentVerticalPadding)
      make.centerX.equalTo(self)
      make.height.equalTo(CGFloat.infoItemHeight)
    }
  }
  
  func setPayAmountCursorLabel(title: String) {
    setCursorLabel(
      withTitle: title,
      inputControl: payAmountInputControl,
      textField: payAmountTextField
    )
  }
  
  func setGetAmountCursorLabel(title: String) {
    setCursorLabel(
      withTitle: title,
      inputControl: getAmountInputControl,
      textField: getAmountTextField
    )
  }
  
  func setCursorLabel(withTitle title: String,
                      inputControl: TKTextInputTextViewControl,
                      textField: TKTextField) {
    inputControl.setupCursorLabel(
      withTitle: title.withTextStyle(.body1, color: .Text.secondary),
      placeholderWidth: textField.placeholderWidth,
      inputText: textField.text
    )
  }
}

private extension TKTextInputTextViewControl {
  static func makeAmountInputControl() -> TKTextInputTextViewControl {
    let inputControl = TKTextInputTextViewControl()
    inputControl.keyboardType = .decimalPad
    return inputControl
  }
}

private extension TKTextFieldInputView {
  static func makeAmountInputView(inputControl: TKTextInputTextViewControl) -> TKTextFieldInputView {
    let inputView = TKTextFieldInputView(textInputControl: inputControl)
    inputView.clearButtonMode = .never
    return inputView
  }
}

private extension CGFloat {
  static let contentVerticalPadding: CGFloat = 16
  static let contentHorizontalPadding: CGFloat = 16
  static let infoItemHeight: CGFloat = 20
}

private extension NSDirectionalEdgeInsets {
  static let contentStackViewPadding = NSDirectionalEdgeInsets(
    top: 0,
    leading: 16,
    bottom: 0,
    trailing: 16
  )
}

