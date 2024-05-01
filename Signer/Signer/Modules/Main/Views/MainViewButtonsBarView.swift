import UIKit
import TKUIKit

final class MainViewButtonsBarView: UIView, ConfigurableView {
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .fillEqually
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 16, bottom: 36, trailing: 16)
    stackView.isLayoutMarginsRelativeArrangement = true
    return stackView
  }()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let buttons: [TKFlatButtonControl<TKFlatButtonTitleIconContent>.Model]
  }
  
  func configure(model: Model) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    model.buttons.forEach { buttonModel in
      let button = TKButton.flatIconTitleButton()
      button.backgroundColor = .Background.page
      button.configure(model: buttonModel)
      stackView.addArrangedSubview(button)
    }
  }
}

private extension MainViewButtonsBarView {
  func setup() {
    addSubview(stackView)
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor)
        .withPriority(.defaultHigh),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        .withPriority(.defaultHigh)
    ])
  }
}
