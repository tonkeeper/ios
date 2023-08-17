//
//  TonChartButtonsView.swift
//  Tonkeeper
//
//  Created by Grigory on 16.8.23..
//

import UIKit

final class TonChartButtonsView: UIView, ConfigurableView {
  
  var didTapButton: ((_ index: Int) -> Void)?
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .fillEqually
    return stackView
  }()
  private var buttons = [TKButton]()
  
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
    let buttons: [TKButton.Model]
  }
  
  func configure(model: Model) {
    buttons.forEach { $0.removeFromSuperview() }
    let buttons = model.buttons.enumerated().map { index, model in
      let button = TKButton(
        configuration: .init(type: .clear,
                             size: .small,
                             shape: .roundedRect,
                             contentInsets: .init(top: 8, left: 16, bottom: 8, right: 16))
      )
      button.configure(model: model)
      button.addAction(.init(handler: { [weak self] in
        self?.didTapButton?(index)
      }), for: .touchUpInside)
      return button
    }
    buttons.forEach {
      stackView.addArrangedSubview($0)
    }
    self.buttons = buttons
  }
  
  // MARK: - Select
  
  func selectButton(at index: Int) {
    buttons.enumerated().forEach { buttonIndex, button in
      let configuration: TKButton.Configuration = buttonIndex == index
      ? .selectedConfiguration 
      : .deselectedConfiguration
      button.configuration = configuration
    }
  }
}

private extension TonChartButtonsView {
  func setup() {
    addSubview(stackView)
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: .verticalSpace),
      stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: .horizontalSpace),
      stackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -.horizontalSpace)
        .withPriority(.defaultHigh),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.verticalSpace)
        .withPriority(.defaultHigh),
      stackView.heightAnchor.constraint(equalToConstant: .buttonsHeight)
    ])
  }
}

private extension CGFloat {
  static let buttonsHeight: CGFloat = 36
  static let horizontalSpace: CGFloat = 27
  static let verticalSpace: CGFloat = 24
}

private extension TKButton.Configuration {
  static let selectedConfiguration = TKButton.Configuration(type: .secondary,
                                                            size: .small,
                                                            shape: .roundedRect,
                                                            contentInsets: .init(top: 8, left: 16, bottom: 8, right: 16))
  static let deselectedConfiguration = TKButton.Configuration(type: .clear,
                                                              size: .small,
                                                              shape: .roundedRect,
                                                              contentInsets: .init(top: 8, left: 16, bottom: 8, right: 16))
}
