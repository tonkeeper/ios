import UIKit
import TKUIKit

final class MainHeaderButtonsView: UIView, ConfigurableView {
  
  private let dividerView = TKDividerBackgroundView()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = .padding
    return stackView
  }()
  
  private let scanButton = TKUIIconButton()
  private let addKeyButton = TKUIIconButton()
  private let settingsButton = TKUIIconButton()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    struct Button {
      let title: String
      let icon: UIImage
      let isEnabled: Bool
      let action: () -> Void
    }
    
    let scanButton: Button
    let addKeyButton: Button
    let settingsButton: Button
  }
  
  func configure(model: Model) {
    configureButton(button: scanButton, model: model.scanButton)
    configureButton(button: addKeyButton, model: model.addKeyButton)
    configureButton(button: settingsButton, model: model.settingsButton)
  }
}

private extension MainHeaderButtonsView {
  func setup() {
    dividerView.numberOfRows = 1
    
    let topRowStackView = UIStackView()
    topRowStackView.axis = .horizontal
    topRowStackView.distribution = .fillEqually
    stackView.addArrangedSubview(topRowStackView)
    
    topRowStackView.addArrangedSubview(scanButton)
    topRowStackView.addArrangedSubview(addKeyButton)
    topRowStackView.addArrangedSubview(settingsButton)
    
    addSubview(dividerView)
    addSubview(stackView)
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    dividerView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(NSDirectionalEdgeInsets.padding)
    }
  }
  
  private func configureButton(button: TKUIIconButton, model: Model.Button) {
    button.configure(model: TKUIIconButton.Model(image: model.icon, title: model.title))
    button.isEnabled = model.isEnabled
    button.addTapAction(model.action)
  }
}

private extension NSDirectionalEdgeInsets {
  static var padding = NSDirectionalEdgeInsets(
    top: 0,
    leading: 16,
    bottom: 36,
    trailing: 16)
}
