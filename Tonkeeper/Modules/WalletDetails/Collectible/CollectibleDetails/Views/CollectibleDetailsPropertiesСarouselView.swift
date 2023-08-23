//
//  CollectibleDetailsPropertiesСarouselView.swift
//  Tonkeeper
//
//  Created by Grigory on 23.8.23..
//

import UIKit

final class CollectibleDetailsPropertiesСarouselView: UIView, ConfigurableView {
  
  private let titleView = ListTitleView()
  private let scrollView: UIScrollView = {
    let scrollView = UIScrollView()
    scrollView.showsHorizontalScrollIndicator = false
    return scrollView
  }()
  private let propertiesStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = .stackViewSpacing
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
    let titleModel: ListTitleView.Model
    let propertiesModels: [CollectibleDetailsPropertyView.Model]
  }

  func configure(model: Model) {
    titleView.configure(model: model.titleModel)
    
    propertiesStackView.subviews.forEach { $0.removeFromSuperview() }
    model.propertiesModels.forEach {
      let view = CollectibleDetailsPropertyView()
      view.configure(model: $0)
      propertiesStackView.addArrangedSubview(view)
    }
  }
}

private extension CollectibleDetailsPropertiesСarouselView {
  func setup() {
    addSubview(titleView)
    addSubview(scrollView)
    scrollView.addSubview(propertiesStackView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    propertiesStackView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      titleView.topAnchor.constraint(equalTo: topAnchor),
      titleView.leftAnchor.constraint(equalTo: leftAnchor),
      titleView.rightAnchor.constraint(equalTo: rightAnchor),

      scrollView.topAnchor.constraint(equalTo: titleView.bottomAnchor),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      scrollView.heightAnchor.constraint(equalToConstant: 70),

      propertiesStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      propertiesStackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      propertiesStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      propertiesStackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      propertiesStackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
    ])
  }
}

private extension CGFloat {
  static let stackViewSpacing: CGFloat = 12
}


