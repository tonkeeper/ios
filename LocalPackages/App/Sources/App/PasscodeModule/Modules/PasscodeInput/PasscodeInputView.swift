import UIKit
import TKUIKit

public final class PasscodeInputView: UIView, ConfigurableView {
  
  let passcodeView = PasscodeDotRowView()
  let titleLabel = UILabel()
  let topContainer = UIView()
  let stackView = UIStackView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Model {
    let title: String
    let keyboardConfiguration: TKKeyboardView.Configuration
  }
  
  public func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(
      .h3,
      color: .Text.primary
    )
  }
}

private extension PasscodeInputView {
  func setup() {
    backgroundColor = .Background.page
    
    stackView.axis = .vertical
    stackView.alignment = .center
    stackView.spacing = .titleBottomSpace
    
    addSubview(topContainer)
    topContainer.addSubview(stackView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(passcodeView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    topContainer.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      topContainer.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      topContainer.leftAnchor.constraint(equalTo: leftAnchor),
      topContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
      topContainer.rightAnchor.constraint(equalTo: rightAnchor),
      
      stackView.centerXAnchor.constraint(equalTo: topContainer.centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: topContainer.centerYAnchor)
    ])
  }
}

private extension CGFloat {
  static let titleBottomSpace: CGFloat = 20
}
