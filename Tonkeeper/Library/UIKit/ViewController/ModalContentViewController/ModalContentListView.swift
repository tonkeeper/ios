//
//  ModalContentListView.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import UIKit

final class ModalContentListView: UIView, ConfigurableView {

  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.content
    view.layer.masksToBounds = true
    view.layer.cornerRadius = 16
    return view
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: [ModalContentViewController.Configuration.ListItem]) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    model.forEach {
      let listItemView = ModalContentListItemView()
      listItemView.configure(model: $0)
      stackView.addArrangedSubview(listItemView)
    }
  }
}

private extension ModalContentListView {
  func setup() {
    addSubview(backgroundView)
    addSubview(stackView)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      backgroundView.topAnchor.constraint(equalTo: topAnchor),
      backgroundView.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      backgroundView.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace),
      backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      stackView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
      stackView.leftAnchor.constraint(equalTo: backgroundView.leftAnchor),
      stackView.rightAnchor.constraint(equalTo: backgroundView.rightAnchor),
      stackView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor)
    ])
  }
}

