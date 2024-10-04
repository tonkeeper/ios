import UIKit
import TKUIKit

final class WalletBalanceHeaderButtonsView: UIView, ConfigurableView {
  
  private let dividerView = TKDividerBackgroundView()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  private let bottomRowStackView: UIStackView = {
    let view = UIStackView()
    view.axis = .horizontal
    view.distribution = .fillEqually
    return view
  }()
  
  private let sendButton = TKIconButton()
  private let recieveButton = TKIconButton()
  private let scanButton = TKIconButton()
  private let swapButton = TKIconButton()
  private let buyButton = TKIconButton()
  private let stakeButton = TKIconButton()
  
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
    let swapButton: Button?
    let buyButton: Button?
    let stakeButton: Button
  }
  
  func configure(model: Model) {

    sendButton.configuration = buttonConfiguration(model: model.sendButton)
    recieveButton.configuration = buttonConfiguration(model: model.recieveButton)
    scanButton.configuration = buttonConfiguration(model: model.scanButton)
    
    bottomRowStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    
    bottomRowStackView.addArrangedSubview(stakeButton)
    stakeButton.configuration = buttonConfiguration(model: model.stakeButton)
    
    if let modelSwapButton = model.swapButton {
      bottomRowStackView.insertArrangedSubview(swapButton, at: 0)
      swapButton.configuration = buttonConfiguration(model: modelSwapButton)
    }
    if let modelBuyButton = model.buyButton {
      bottomRowStackView.insertArrangedSubview(buyButton, at: 1)
      buyButton.configuration = buttonConfiguration(model: modelBuyButton)
    }
    switch bottomRowStackView.arrangedSubviews.count {
    case 1:
      bottomRowStackView.insertArrangedSubview(UIView(), at: 0)
      bottomRowStackView.insertArrangedSubview(UIView(), at: 2)
    case 2:
      let v1 = UIView()
      v1.backgroundColor = .clear
      bottomRowStackView.insertArrangedSubview(UIView(), at: 2)
    default: break
    }
  }
}

private extension WalletBalanceHeaderButtonsView {
  func setup() {
    dividerView.numberOfRows = 2
    
    let topRowStackView = UIStackView()
    topRowStackView.axis = .horizontal
    topRowStackView.distribution = .fillEqually
    stackView.addArrangedSubview(topRowStackView)

    stackView.addArrangedSubview(bottomRowStackView)
    
    topRowStackView.addArrangedSubview(sendButton)
    topRowStackView.addArrangedSubview(recieveButton)
    topRowStackView.addArrangedSubview(scanButton)
    
    bottomRowStackView.addArrangedSubview(stakeButton)
    
    addSubview(dividerView)
    addSubview(stackView)
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(NSDirectionalEdgeInsets.padding)
    }
    
    dividerView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(NSDirectionalEdgeInsets.padding)
    }
  }
  
  private func buttonConfiguration(model: Model.Button) -> TKIconButton.Configuration {
    return TKIconButton.Configuration(
      title: model.title,
      icon: model.icon,
      isEnable: model.isEnabled,
      action: model.action
    )
  }
}

private extension NSDirectionalEdgeInsets {
  static var padding = NSDirectionalEdgeInsets(
    top: 0,
    leading: 16,
    bottom: 20,
    trailing: 16)
}
