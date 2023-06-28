//
//  WelcomeWelcomeView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import UIKit

final class WelcomeView: UIView, ConfigurableView {

  let scrollView = UIScrollView()
  let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 2
    return label
  }()
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = .listInterItemsSpace
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
    let title: NSAttributedString
    let items: [WelcomeListItem.Model]
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    
    contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    model.items.forEach {
      let itemView = WelcomeListItem()
      itemView.configure(model: $0)
      contentStackView.addArrangedSubview(itemView)
    }
  }
}

// MARK: - Private

private extension WelcomeView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(scrollView)
    scrollView.addSubview(titleLabel)
    scrollView.addSubview(contentStackView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor, constant: .contentSideSpace),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor, constant: -.contentSideSpace),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      titleLabel.topAnchor.constraint(equalTo: scrollView.topAnchor),
      titleLabel.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      titleLabel.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      
      contentStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: .listTopSpace),
      contentStackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      contentStackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
    ])
  }
}

private extension CGFloat {
  static let contentSideSpace: CGFloat = 32
  static let listTopSpace: CGFloat = 32
  static let listInterItemsSpace: CGFloat = 24
}
