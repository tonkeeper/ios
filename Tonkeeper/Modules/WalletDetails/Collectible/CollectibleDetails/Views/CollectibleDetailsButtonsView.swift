//
//  CollectibleDetailsButtonsView.swift
//  Tonkeeper
//
//  Created by Grigory on 25.8.23..
//

import UIKit

final class CollectibleDetailsButtonsView: UIView, ConfigurableView {
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.spacing = .interButtonSpace
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
      let title: String
      let configuration: TKButton.Configuration
      let isEnabled: Bool
      let tapAction: (() -> Void)?
      let description: NSAttributedString?
    }
    
    let buttonsModels: [Button]
  }

  func configure(model: Model) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    
    model.buttonsModels.forEach { buttonConfiguration in
      let button = TKButton(configuration: buttonConfiguration.configuration)
      button.title = buttonConfiguration.title
      button.isEnabled = buttonConfiguration.isEnabled
      button.addAction(.init(handler: { buttonConfiguration.tapAction?() }), for: .touchUpInside)
      stackView.addArrangedSubview(button)
      
      if let description = buttonConfiguration.description {
        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = description
        stackView.addArrangedSubview(label)
        stackView.setCustomSpacing(.beforeDescriptionSpace, after: button)
      }
    }
  }
}

private extension CollectibleDetailsButtonsView {
  func setup() {
    addSubview(stackView)
//    addSubview(scrollView)
//    scrollView.addSubview(propertiesStackView)
//
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
//    scrollView.translatesAutoresizingMaskIntoConstraints = false
//    propertiesStackView.translatesAutoresizingMaskIntoConstraints = false
//
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: .stackViewVerticalSpace),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.stackViewVerticalSpace),
//      titleView.topAnchor.constraint(equalTo: topAnchor),
//      titleView.leftAnchor.constraint(equalTo: leftAnchor),
//      titleView.rightAnchor.constraint(equalTo: rightAnchor),
//
//      scrollView.topAnchor.constraint(equalTo: titleView.bottomAnchor),
//      scrollView.leftAnchor.constraint(equalTo: leftAnchor),
//      scrollView.rightAnchor.constraint(equalTo: rightAnchor),
//      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.scrollViewBottomSpace),
//      scrollView.heightAnchor.constraint(equalToConstant: .scrollViewHeight),
//
//      propertiesStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
//      propertiesStackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
//      propertiesStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
//      propertiesStackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
//      propertiesStackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
    ])
  }
}

private extension CGFloat {
  static let stackViewVerticalSpace: CGFloat = 16
  static let beforeDescriptionSpace: CGFloat = 12
  static let interButtonSpace: CGFloat = 16
//  static let stackViewSpacing: CGFloat = 12
//  static let scrollViewHeight: CGFloat = 70
//  static let scrollViewBottomSpace: CGFloat = 20
}



