import UIKit
import TKUIKit

final class TokenDetailsHeaderButtonsView: UIView, ConfigurableView {
  
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    struct Button {
      let configuration: TKUIIconButton.Model
      let isEnabled: Bool
      let action: () -> Void
      
      init(configuration: TKUIIconButton.Model,
           isEnabled: Bool = true,
           action: @escaping () -> Void) {
        self.configuration = configuration
        self.isEnabled = isEnabled
        self.action = action
      }
    }
    let buttons: [Button]
  }
  
  func configure(model: Model) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    
    let rowStackView = UIStackView()
    rowStackView.distribution = .fillEqually
    stackView.addArrangedSubview(rowStackView)
    
    model.buttons.forEach {
      let button = TKUIIconButton()
      button.configure(model: $0.configuration)
      button.isEnabled = $0.isEnabled
      button.addTapAction($0.action)
      rowStackView.addArrangedSubview(button)
    }
  }
}

private extension TokenDetailsHeaderButtonsView {
  func setup() {
    addSubview(stackView)
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: NSDirectionalEdgeInsets.padding.top),
      stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: NSDirectionalEdgeInsets.padding.leading),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -NSDirectionalEdgeInsets.padding.bottom),
      stackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -NSDirectionalEdgeInsets.padding.trailing),
      stackView.heightAnchor.constraint(equalToConstant: 80)
    ])
  }
}

private extension NSDirectionalEdgeInsets {
  static var padding = NSDirectionalEdgeInsets(
    top: 0,
    leading: 16,
    bottom: 20,
    trailing: 16)
}
