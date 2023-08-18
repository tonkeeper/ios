//
//  TwinButton.swift
//  Tonkeeper
//
//  Created by Grigory on 18.8.23..
//

import UIKit

final class TwinButton: UIView, ConfigurableView {
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .center
    return stackView
  }()
  
  let rightButton: TKButton = {
    let button = TKButton(configuration: .init(type: .clear, size: .xsmall, shape: .circle, contentInsets: .init(top: 8, left: 4, bottom: 8, right: 4)))
    return button
  }()
  
  let leftButton: TKButton = {
    let button = TKButton(configuration: .init(type: .clear, size: .xsmall, shape: .circle, contentInsets: .init(top: 8, left: 4, bottom: 8, right: 4)))
    return button
  }()
  
  let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let leftButtonModel: TKButton.Model
    let rightButtonModel: TKButton.Model
  }
  
  func configure(model: Model) {
    leftButton.configure(model: model.leftButtonModel)
    rightButton.configure(model: model.rightButtonModel)
  }
}

private extension TwinButton {
  func setup() {
    backgroundColor = .Background.content
    layer.cornerRadius = .cornerRadiues
  
    addSubview(stackView)
    stackView.addArrangedSubview(leftButton)
    stackView.addArrangedSubview(separatorView)
    stackView.addArrangedSubview(rightButton)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    separatorView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      separatorView.widthAnchor.constraint(equalToConstant: 1),
      separatorView.heightAnchor.constraint(equalToConstant: 16)
    ])
  }
}

private extension CGFloat {
  static let cornerRadiues: CGFloat = 16
}
