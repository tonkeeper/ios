import UIKit
import TKUIKit

final class WalletBalanceHeaderButtonsView: UIView, ConfigurableView {
  
  private let dividerView = TKDividerBackgroundView()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = .padding
    return stackView
  }()
  
  private let sendButton = TKUIIconButton()
  private let recieveButton = TKUIIconButton()
  private let scanButton = TKUIIconButton()
  private let swapButton = TKUIIconButton()
  private let buyButton = TKUIIconButton()
  private let stakeButton = TKUIIconButton()
  
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
    
    let sendButton: Button
    let recieveButton: Button
    let scanButton: Button
    let swapButton: Button
    let buyButton: Button
    let stakeButton: Button
  }
  
  func configure(model: Model) {
    configureButton(button: sendButton, model: model.sendButton)
    configureButton(button: recieveButton, model: model.recieveButton)
    configureButton(button: scanButton, model: model.scanButton)
    configureButton(button: swapButton, model: model.swapButton)
    configureButton(button: buyButton, model: model.buyButton)
    configureButton(button: stakeButton, model: model.stakeButton)
  }
}

private extension WalletBalanceHeaderButtonsView {
  func setup() {
    dividerView.numberOfRows = 2
    
    let topRowStackView = UIStackView()
    topRowStackView.axis = .horizontal
    topRowStackView.distribution = .fillEqually
    stackView.addArrangedSubview(topRowStackView)
    
    let bottomRowStackView = UIStackView()
    bottomRowStackView.axis = .horizontal
    bottomRowStackView.distribution = .fillEqually
    stackView.addArrangedSubview(bottomRowStackView)
    
    topRowStackView.addArrangedSubview(sendButton)
    topRowStackView.addArrangedSubview(recieveButton)
    topRowStackView.addArrangedSubview(scanButton)
    bottomRowStackView.addArrangedSubview(swapButton)
    bottomRowStackView.addArrangedSubview(buyButton)
    bottomRowStackView.addArrangedSubview(stakeButton)
    
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
    bottom: 20,
    trailing: 16)
}
