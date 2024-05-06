import UIKit
import TKUIKit
import SnapKit

final class SignConfirmationBocView: UIView, ConfigurableView {
  
  let textView: UITextView = {
    let textView = UITextView()
    textView.isEditable = false
    textView.isScrollEnabled = false
    textView.isSelectable = false
    textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
    textView.textColor = .Text.primary
    textView.backgroundColor = .clear
    textView.textContainer.maximumNumberOfLines = 4
    textView.textContainer.lineBreakMode = .byTruncatingTail
    textView.textContainer.lineFragmentPadding = 0
    textView.textContainerInset = .init(
      top: 0,
      left: 0,
      bottom: 0,
      right: 0)
    return textView
  }()
  
  let emulateButton = TKButton()
  let copyButton = TKButton()
  
  private let buttonsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.spacing = 8
    return stackView
  }()
  private let containerView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let boc: String
    let emulateButtonConfiguration: TKButton.Configuration
    let copyButtonConfiguration: TKButton.Configuration
  }
  
  func configure(model: Model) {
    textView.text = model.boc
    emulateButton.configuration = model.emulateButtonConfiguration
    copyButton.configuration = model.copyButtonConfiguration
  }
}

private extension SignConfirmationBocView {
  func setup() {
    backgroundColor = .Background.content
    layer.cornerRadius = 16
    layer.masksToBounds = true
    
    addSubview(containerView)
    containerView.addSubview(textView)
    containerView.addSubview(buttonsStackView)
    buttonsStackView.addArrangedSubview(emulateButton)
    buttonsStackView.addArrangedSubview(copyButton)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    containerView.snp.makeConstraints { make in
      make.edges.equalTo(UIEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)).priority(.high)
    }
    
    textView.snp.makeConstraints { make in
      make.top.left.right.equalTo(containerView)
    }
    
    buttonsStackView.snp.makeConstraints { make in
      make.top.equalTo(textView.snp.bottom).offset(8)
      make.left.right.bottom.equalTo(containerView)
    }
  }
}
