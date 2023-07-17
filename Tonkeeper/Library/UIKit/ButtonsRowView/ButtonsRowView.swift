//
//  ButtonsRowView.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

final class ButtonsRowView: UIView, ConfigurableView {
  
  struct Model {
    enum ButtonType {
      case buy
      case send
      case receive
      case sell
      case swap
      
      var title: String {
        switch self {
        case .buy: return "Buy TON"
        case .receive: return "Receive"
        case .sell: return "Sell"
        case .send: return "Send"
        case .swap: return "Swap"
        }
      }
      
      var icon: UIImage? {
        switch self {
        case .buy: return .Icons.Buttons.Wallet.buy
        case .receive: return .Icons.Buttons.Wallet.recieve
        case .sell: return .Icons.Buttons.Wallet.sell
        case .send: return .Icons.Buttons.Wallet.send
        case .swap: return .Icons.Buttons.Wallet.swap
        }
      }
    }
    
    struct ButtonModel {
      let type: ButtonType
      let handler: (() -> Void)?
    }
    
    let buttons: [ButtonModel]
  }
  
  var buttons = [IconButton]() {
    didSet {
      reloadButtons()
    }
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: Model) {
    let buttons = model.buttons.map { buttonModel in
      let iconButton = IconButton()
      iconButton.configure(model: .init(
        buttonModel: .init(icon: buttonModel.type.icon),
        title: buttonModel.type.title)
      )
      iconButton.addAction(.init(handler: {
        buttonModel.handler?()
      }), for: .touchUpInside)
      return iconButton
    }
    self.buttons = buttons
  }
}

private extension ButtonsRowView {
  func setup() {
    stackView.distribution = .fillEqually
    
    addSubview(stackView)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
  
  func reloadButtons() {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    buttons.forEach { stackView.addArrangedSubview($0) }
  }
}
