//
//  ModalCardViewController+HeaderView.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 20.10.2023.
//

import UIKit
import TKUIKit

extension ModalCardViewController {
  final class HeaderView: UIView, ConfigurableView {
    private let viewController: UIViewController
    
    private let stackView: UIStackView = {
      let stackView = UIStackView()
      stackView.axis = .vertical
      return stackView
    }()
    
    // MARK: - Init
    
    init(viewController: UIViewController) {
      self.viewController = viewController
      super.init(frame: .zero)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - ConfigurableView
    
    func configure(model: Configuration.Header) {
      ModalCardViewBuilder.buildViews(items: model.items, viewController: viewController).forEach { view in
        stackView.addArrangedSubview(view)
      }
    }
  }
}

private extension ModalCardViewController.HeaderView {
  func setup() {
    addSubview(stackView)
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}

private extension CGFloat {
  static let descriptionBottomSpace: CGFloat = 4
}
