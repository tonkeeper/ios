import UIKit
import SnapKit

public final class TKSwapTokenField: UIView {
  
  public var swapTokenFieldState = TKSwapTokenFieldState() {
    didSet {
      didUpdateState()
    }
  }
  
  private let topView = UIView()
  private let titleLabel = UILabel()
  private let balanceLabel = UILabel()
  private let maxLabel = UILabel()
  private let tokenView = TKSwapTokenFieldTokenView()
  public let bottomStackView = UIStackView()
  
  public var onMaxTapped: (() -> Void)? = nil
  public var onChooseTapped: (() -> Void)? = nil
  public var didUpdateAmount: ((String) -> Void)? = nil

  private lazy var textInputControl: TKTextInputTextFieldControl = {
    let textInputControl = TKTextInputTextFieldControl()
    textInputControl.keyboardType = .decimalPad
    textInputControl.font = TKTextStyle.num2.font
    textInputControl.textAlignment = .right
    textInputControl.placeholder = "0"
    return textInputControl
  }()
  private lazy var amountTextField = TKTextFieldInputView(textInputControl: textInputControl)
  
  public enum Mode {
    case sell
    case buy
  }
  let mode: Mode
  public init(mode: Mode) {
    self.mode = mode
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
}

private extension TKSwapTokenField {
  func setup() {
    addSubview(topView)
    topView.snp.makeConstraints { make in
      make.horizontalEdges.equalTo(self)
      make.top.equalTo(snp.top)
      make.height.equalTo(108)
    }

    let rightStackView = UIStackView()

    topView.addSubview(titleLabel)
    topView.addSubview(rightStackView)
    topView.addSubview(tokenView)
    topView.addSubview(amountTextField)

    titleLabel.textColor = .Text.secondary
    titleLabel.font = TKTextStyle.body2.font
    titleLabel.snp.makeConstraints { make in
      make.left.equalTo(self).inset(16)
      make.top.equalTo(self).inset(mode == .sell ? 16 : 32)
    }
    
    balanceLabel.textColor = .Text.secondary
    balanceLabel.font = TKTextStyle.body2.font

    maxLabel.attributedText = "MAX".withTextStyle(
      .body2,
      color: .Accent.blue,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    maxLabel.isUserInteractionEnabled = true
    maxLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(maxPressed)))

    rightStackView.spacing = 8
    rightStackView.addArrangedSubview(balanceLabel)
    rightStackView.addArrangedSubview(maxLabel)
    rightStackView.snp.makeConstraints { make in
      make.right.equalTo(self).inset(16)
      make.top.equalTo(self).inset(mode == .sell ? 0 : 16)
      make.height.equalTo(44)
    }
    
    tokenView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(chooseTapped)))
    tokenView.snp.makeConstraints { make in
      make.top.equalTo(titleLabel.snp.bottom)
      make.left.equalTo(self).inset(16)
    }

    amountTextField.clearButtonMode = .never
    amountTextField.snp.makeConstraints { make in
      make.left.equalTo(tokenView.snp.right)
      make.right.equalTo(self).inset(16)
      make.top.equalTo(rightStackView.snp.bottom).inset(0)
      make.height.equalTo(36)
    }
    amountTextField.didUpdateText = { [weak self] text in
      self?.didUpdateAmount?(text)
    }
    
    // bottom stack view
    addSubview(bottomStackView)
    bottomStackView.alignment = .fill
    bottomStackView.snp.makeConstraints { make in
      make.top.equalTo(topView.snp.bottom)
      make.horizontalEdges.equalTo(self)
      make.bottom.equalTo(self)
    }

    didUpdateState()
    
    layer.borderWidth = 1.5
    layer.cornerRadius = 16
  }
  
  @objc func chooseTapped() {
    onChooseTapped?()
  }
  
  @objc func maxPressed() {
    onMaxTapped?()
  }
  
  func didUpdateState() {
    UIView.animate(withDuration: 0.2) { [weak self] in
      guard let self else {return}
      backgroundColor = swapTokenFieldState.backgroundColor
      layer.borderColor = swapTokenFieldState.borderColor.cgColor
    }
    topView.isUserInteractionEnabled = !swapTokenFieldState.previewMode
    titleLabel.text = swapTokenFieldState.title
    balanceLabel.text = swapTokenFieldState.token?.balance
    maxLabel.isHidden = !swapTokenFieldState.isSellingToken || swapTokenFieldState.previewMode
    if let token = swapTokenFieldState.token {
      tokenView.imageView.isHidden = false
      tokenView.label.text = token.name
      tokenView.image = token.image
    } else {
      tokenView.imageView.isHidden = true
      tokenView.label.text = "CHOOSE"
    }
    textInputControl.text = (textInputControl.text != "0" && swapTokenFieldState.amount == "0") ? "" : swapTokenFieldState.amount
  }
}
