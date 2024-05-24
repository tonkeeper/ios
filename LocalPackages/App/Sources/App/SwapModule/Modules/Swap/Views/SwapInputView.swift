import UIKit
import TKUIKit

final class SwapInputView: UIView {

  var swapField: SwapField {
    didSet { updateViews() }
  }

  var didTapChooseToken: ((SwapField) -> Void)?

  private let backgroundView = TKBackgroundView()
  private let headerView = UIView()
  private let tokenView = UIView()
  private let actionLabel = UILabel()
  private let balanceLabel = UILabel()

  lazy var maxButton: TKButton = {
    var configuration = TKButton.Configuration.accentButtonConfiguration(padding: .zero)
    configuration.textStyle = .label2
    configuration.tapAreaInsets = .init(top: -20, left: -60, bottom: -20, right: -20)
    configuration.content.title = .plainString("MAX")
    return TKButton(configuration: configuration)
  }()

  let chooseTokenView = SwapInputTokenView()

  private lazy var textInputControl: TKTextInputTextFieldControl = {
    let textInputControl = TKTextInputTextFieldControl()
    textInputControl.keyboardType = .decimalPad
    textInputControl.textAlignment = .right
    textInputControl.adjustsFontSizeToFitWidth = true
    textInputControl.font = TKTextStyle.num2.font
    return textInputControl
  }()

  lazy var amountTextField: TKTextField = {
    let inputView = TKTextFieldInputView(textInputControl: textInputControl)
    inputView.clearButtonMode = .never
    let configuration = TKTextField.Configuration(
      edgePaddings: UIEdgeInsets(top: 6, left: 0, bottom: 2, right: 0),
      highlightBorder: false
    )
    let textField = TKTextField(textFieldInputView: inputView, configuration: configuration)
    return textField
  }()

  init(state: SwapField) {
    self.swapField = state
    super.init(frame: .zero)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: CGSize {
    return CGSize(width: UIView.noIntrinsicMetric, height: 108)
  }

  func updateTotalBalance(_ balanceString: String?) {
    self.balanceLabel.attributedText = (balanceString ?? "").withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .right
    )
  }
}

private extension SwapInputView {
  func setup() {
    addSubview(backgroundView)
    addSubview(headerView)
    addSubview(tokenView)

    headerView.addSubview(actionLabel)
    headerView.addSubview(balanceLabel)
    headerView.addSubview(maxButton)

    maxButton.alpha = swapField == .send ? 1 : 0

    tokenView.addSubview(chooseTokenView)
    tokenView.addSubview(amountTextField)

    amountTextField.text = "0"

    actionLabel.attributedText = (swapField == .send ? "Send" : "Receive").withTextStyle(
      .body2,
      color: .Text.secondary
    )

    headerView.clipsToBounds = false
    maxButton.clipsToBounds = false

    chooseTokenView.didTap = { [weak self] in
      guard let self else { return }
      self.didTapChooseToken?(self.swapField)
    }
    
    setupConstraints()
  }

  func setupConstraints() {
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    headerView.snp.makeConstraints { make in
      make.horizontalEdges.equalTo(self)
      make.top.equalTo(swapField == .send ? 0 : 12)
      make.height.equalTo(44)
    }
    tokenView.snp.makeConstraints { make in
      make.horizontalEdges.equalTo(self)
      make.top.equalTo(headerView.snp.bottom)
      make.height.equalTo(52)
    }
    actionLabel.snp.makeConstraints { make in
      make.left.top.equalTo(16)
    }
    chooseTokenView.snp.makeConstraints { make in
      make.left.equalTo(tokenView.snp.left).inset(16)
      make.top.equalTo(tokenView.snp.top)
    }
    amountTextField.snp.makeConstraints { make in
      make.left.equalTo(chooseTokenView.snp.right)
      make.top.equalTo(chooseTokenView.snp.top)
      make.right.equalTo(tokenView.snp.right).inset(16)
    }
    maxButton.snp.makeConstraints { make in
      make.top.equalTo(16)
      make.right.equalTo(headerView).inset(16)
    }
    balanceLabel.snp.makeConstraints { make in
      make.top.equalTo(16)
      if swapField == .send {
        make.right.equalTo(maxButton.snp.left).offset(-8)
      } else {
        make.right.equalTo(headerView).offset(-16)
      }
    }
  }

  func updateViews() {
    balanceLabel.snp.remakeConstraints { make in
      make.top.equalTo(16)
      if swapField == .send {
        make.right.equalTo(maxButton.snp.left).offset(-8)
      } else {
        make.right.equalTo(headerView).inset(16)
      }
    }
    headerView.snp.updateConstraints { make in
      make.top.equalTo(swapField == .send ? 0 : 12)
    }
    UIView.animate(withDuration: 0.125, delay: 0, options: .overrideInheritedOptions) {
      self.actionLabel.alpha = 0.5
    } completion: { _ in
      self.actionLabel.attributedText = (self.swapField == .send ? "Send" : "Receive").withTextStyle(
        .body2,
        color: .Text.secondary
      )
      UIView.animate(withDuration: 0.125, delay: 0, options: .overrideInheritedOptions) {
        self.actionLabel.alpha = 1
      }
    }
    UIView.animate(withDuration: 0.25, delay: 0, options: .overrideInheritedOptions) {
      self.maxButton.alpha = self.swapField == .send ? 1 : 0
      self.layoutIfNeeded()
    }
  }
}
