import UIKit
import TKUIKit
import SnapKit

final class BuySellDetailsView: UIView {
  
  // MARK: - Views
  
  let scrollView = TKUIScrollView()
  let serviceInfoContainerView = ServiceInfoContainerView()
  
  let payAmountInputControl: TKTextInputTextViewControl = .makeAmountInputControl()
  let getAmountInputControl: TKTextInputTextViewControl = .makeAmountInputControl()
  
  lazy var payAmountTextField: TKTextField = .makeAmountTextField(inputControl: payAmountInputControl)
  lazy var getAmountTextField: TKTextField = .makeAmountTextField(inputControl: getAmountInputControl)
  
  let convertedRateContainer = ListDescriptionContainerView()
  
  let serviceProvidedLabel = UILabel()
  let infoButtonsContainer = InfoButtonsContainerView()
  
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 0
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 0,
      trailing: 16
    )
    return stackView
  }()
  
  let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
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
    contentStackView.addArrangedSubview(convertedRateContainer)
    
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

private extension TKTextField {
  static func makeAmountTextField(inputControl: TKTextInputTextViewControl) -> TKTextField {
    let inputView = TKTextFieldInputView(textInputControl: inputControl)
    inputView.clearButtonMode = .never
    return TKTextField(textFieldInputView: inputView)
  }
}

private extension CGFloat {
  static let contentVerticalPadding: CGFloat = 16
  static let contentHorizontalPadding: CGFloat = 16
  static let infoItemHeight: CGFloat = 20
}
