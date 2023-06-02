//
//  ModalContentActionBarView.swift
//  Tonkeeper
//
//  Created by Grigory on 3.6.23..
//

import UIKit

final class ModalContentActionBarView: UIView, ConfigurableView {
  
  private let itemsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = .contentSpacing
    return stackView
  }()
  
  private let backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.page
    return view
  }()
  
  private var stackViewBottomConstraint: NSLayoutConstraint?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    stackViewBottomConstraint?.constant = -(safeAreaInsets.bottom + .contentSpacing)
  }
  
  func configure(model: ModalContentViewController.Configuration.ActionBar) {
    model.items.forEach { item in
      switch item {
      case let .buttons(buttonModels):
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = .contentSpacing
        buttonModels.forEach { buttonModel in
          let button = TKButton(configuration: buttonModel.configuration)
          button.titleLabel.text = buttonModel.title
          stackView.addArrangedSubview(button)
        }
        itemsStackView.addArrangedSubview(stackView)
      }
    }
  }
}

private extension ModalContentActionBarView {
  func setup() {
    addSubview(backgroundView)
    addSubview(itemsStackView)
    
    itemsStackView.translatesAutoresizingMaskIntoConstraints = false
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    
    stackViewBottomConstraint = itemsStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
    stackViewBottomConstraint?.isActive = true
    NSLayoutConstraint.activate([
      backgroundView.topAnchor.constraint(equalTo: topAnchor),
      backgroundView.leftAnchor.constraint(equalTo: leftAnchor),
      backgroundView.rightAnchor.constraint(equalTo: rightAnchor),
      backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      itemsStackView.topAnchor.constraint(equalTo: topAnchor, constant: .contentSpacing),
      itemsStackView.leftAnchor.constraint(equalTo: leftAnchor, constant: .contentSpacing),
      itemsStackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -.contentSpacing)
    ])
  }
}

private extension CGFloat {
  static let itemsSpacing: CGFloat = 16
  static let contentSpacing: CGFloat = 16
}
