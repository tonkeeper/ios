import UIKit
import TKUIKit

final class SlippageInputContainerView: UIView, ConfigurableView {
  
  enum SlippageState {
    enum Fixed: Decimal {
      case one = 1
      case three = 3
      case five = 5
      
      var stringValue: String {
        "\(rawValue)"
      }
    }
    
    case customPercent(String)
    case fixedPercent(Fixed)
    
    var stringValue: String {
      switch self {
      case .customPercent(let string):
        return string
      case .fixedPercent(let fixed):
        return fixed.stringValue
      }
    }
    
    var decimalValue: Decimal? {
      switch self {
      case .customPercent(let string):
        return Decimal(string: string)
      case .fixedPercent(let fixed):
        return fixed.rawValue
      }
    }
  }
  
  private var didChangeSlippage: ((SlippageState) -> Void)?
  
  var slippageState: SlippageState = .fixedPercent(.one) {
    didSet {
      didChangeSlippage?(slippageState)
      didUpdateSlippageState()
    }
  }
  
  private(set) lazy var customSlippageTextField = TKTextField(textFieldInputView: customSlippageInputView)
  private(set) lazy var customSlippageInputControl: TKTextInputTextViewControl = .makeCustomSlippageInputControl()
  private lazy var customSlippageInputView: TKTextFieldInputView = .makeCustomSlippageInputView(inputControl: customSlippageInputControl)
  
  private let customSlippageTextFieldPlaceholder = UILabel()
  
  private let leftFixedSlippageButton = SlippagePercentButton()
  private let centerFixedSlippageButton = SlippagePercentButton()
  private let rightFixedSlippageButton = SlippagePercentButton()
  
  private let slippageButtonsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .fillEqually
    stackView.spacing = 12
    return stackView
  }()
  
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 12
    return stackView
  }()
  
  override var intrinsicContentSize: CGSize { sizeThatFits(bounds.size) }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return contentStackView.sizeThatFits(size)
  }
  
  struct Model {
    let textFieldplaceholder: String
    let slippageState: SlippageState
    let onSlippageChange: ((SlippageState) -> Void)?
  }
  
  func configure(model: Model) {
    customSlippageTextFieldPlaceholder.attributedText = model.textFieldplaceholder.withTextStyle(.body1, color: .Text.secondary)
    slippageState = model.slippageState
    if case .customPercent(let string) = model.slippageState {
      didInputCustomSlippageText(string)
    }
    
    didChangeSlippage = { newSlippage in
      model.onSlippageChange?(newSlippage)
    }
    
    invalidateIntrinsicContentSize()
  }
}

private extension SlippageInputContainerView {
  func setup() {
    customSlippageTextField.placeholder = ""
    customSlippageInputView.padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    customSlippageInputControl.setupCursorLabel(
      withTitle: "%".withTextStyle(.body1, color: .Text.secondary),
      placeholderWidth: 0,
      inputText: ""
    )
    customSlippageInputControl.cursorLabel?.isHidden = true
    
    leftFixedSlippageButton.configure(model: .init(title: "1 %"))
    centerFixedSlippageButton.configure(model: .init(title: "3 %"))
    rightFixedSlippageButton.configure(model: .init(title: "5 %"))
    
    customSlippageInputControl.addSubview(customSlippageTextFieldPlaceholder)
    
    slippageButtonsStackView.addArrangedSubview(leftFixedSlippageButton)
    slippageButtonsStackView.addArrangedSubview(centerFixedSlippageButton)
    slippageButtonsStackView.addArrangedSubview(rightFixedSlippageButton)
    
    contentStackView.addArrangedSubview(customSlippageTextField)
    contentStackView.addArrangedSubview(slippageButtonsStackView)
    addSubview(contentStackView)
    
    setupConstraints()
    setupBindings()
  }
  
  func setupConstraints() {
    contentStackView.snp.makeConstraints { make in
      make.left.right.top.equalTo(self)
      make.bottom.equalTo(self).inset(16)
    }
    
    customSlippageTextField.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.textFieldHeight)
    }
    
    customSlippageTextFieldPlaceholder.snp.makeConstraints { make in
      make.edges.equalTo(customSlippageInputControl)
    }
  }
  
  func setupBindings() {
    customSlippageTextField.didUpdateText = { [weak self] text in
      self?.didInputCustomSlippageText(text)
    }
    
    customSlippageTextField.didBeginEditing = { [weak self] in
      self?.didBeginEditingTextField()
    }
    
    customSlippageInputView.didEndEditing = { [weak self] in
      self?.didEndEditingTextField()
    }
    
    leftFixedSlippageButton.addTapAction { [weak self] in
      self?.didSelectLeftButtton()
    }
    
    centerFixedSlippageButton.addTapAction { [weak self] in
      self?.didSelectCenterButtton()
    }

    rightFixedSlippageButton.addTapAction { [weak self] in
      self?.didSelectRightButtton()
    }
  }
  
  func didBeginEditingTextField() {
    if let inputText = customSlippageTextField.text, !inputText.isEmpty {
      slippageState = .customPercent(inputText)
    } else {
      deselectButtons()
    }
  }
  
  func didEndEditingTextField() {
    // Start checking if textfield input is valid
    if let inputText = customSlippageTextField.text, inputText.isEmpty {
      slippageState = .defaultSlippage
    } else if case .customPercent(let string) = slippageState, !string.isEmpty {
      // Check if last char is . or , then remove it
      if let lastChar = string.last, lastChar.isDecimalSeparator {
        customSlippageTextField.text = String(string.dropLast(1))
      }
      // If value == 0 then set default slippageState
      if let decimalValue = slippageState.decimalValue, decimalValue == 0 {
        slippageState = .defaultSlippage
      } else {
        customSlippageTextField.textFieldState = .active
      }
    } else {
      customSlippageTextField.textFieldState = .inactive
      didUpdateSlippageState()
    }
  }
  
  func didInputCustomSlippageText(_ text: String) {
    customSlippageTextFieldPlaceholder.isHidden = !text.isEmpty
    customSlippageInputControl.cursorLabel?.isHidden = text.isEmpty
    customSlippageTextField.textFieldState = text.isEmpty ? .error : .active
    if !text.isEmpty {
      slippageState = .customPercent(text)
    }
  }
  
  func didSelectLeftButtton() {
    slippageState = .fixedPercent(.one)
  }
  
  func didSelectCenterButtton() {
    slippageState = .fixedPercent(.three)
  }
  
  func didSelectRightButtton() {
    slippageState = .fixedPercent(.five)
  }
  
  func didUpdateSlippageState() {
    deselectButtons()
    switch slippageState {
    case .customPercent(let string):
      customSlippageTextField.text = string
      customSlippageTextField.textFieldState = .active
    case .fixedPercent(let fixed):
      customSlippageTextField.textFieldState = .inactive
      switch fixed {
      case .one:
        leftFixedSlippageButton.isSelected = true
      case .three:
        centerFixedSlippageButton.isSelected = true
      case .five:
        rightFixedSlippageButton.isSelected = true
      }
    }
  }
  
  func deselectButtons() {
    leftFixedSlippageButton.isSelected = false
    centerFixedSlippageButton.isSelected = false
    rightFixedSlippageButton.isSelected = false
  }
}

private extension TKTextInputTextViewControl {
  static func makeCustomSlippageInputControl() -> TKTextInputTextViewControl {
    let inputControl = TKTextInputTextViewControl()
    inputControl.keyboardType = .decimalPad
    return inputControl
  }
}

private extension TKTextFieldInputView {
  static func makeCustomSlippageInputView(inputControl: TKTextInputTextViewControl) -> TKTextFieldInputView {
    let inputView = TKTextFieldInputView(textInputControl: inputControl)
    inputView.clearButtonMode = .never
    return inputView
  }
}

private extension SlippageInputContainerView.SlippageState {
  static let defaultSlippage = SlippageInputContainerView.SlippageState.fixedPercent(.one)
}

private extension Character {
  var isDecimalSeparator: Bool {
    [",", "."].contains(self)
  }
}

private extension CGFloat {
  static let textFieldHeight: CGFloat = 56
}
