//
//  SettingsListFooterView.swift
//  Tonkeeper
//
//  Created by Grigory on 13.10.23..
//

import UIKit
import Lottie

final class SettingsListFooterView: UIView, ConfigurableView {
  private let diamondView: LottieAnimationView = {
    let view = LottieAnimationView(name: .diamondAnimationName)
    view.backgroundBehavior = .pauseAndRestore
    view.contentMode = .scaleAspectFit
    return view
  }()
  
  private let appTitleLabel: UILabel = {
    let label = UILabel()
    label.textAlignment = .center
    label.textColor = .Text.primary
    label.applyTextStyleFont(.label2)
    return label
  }()
  
  private let versionLabel: UILabel = {
    let label = UILabel()
    label.textAlignment = .center
    label.textColor = .Text.secondary
    label.applyTextStyleFont(.label3)
    return label
  }()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
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
    let appName: String
    let version: String
  }
  
  func configure(model: Model) {
    appTitleLabel.text = model.appName
    versionLabel.text = model.version
  }
}

private extension SettingsListFooterView {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(diamondView)
    stackView.addArrangedSubview(appTitleLabel)
    stackView.setCustomSpacing(4, after: appTitleLabel)
    stackView.addArrangedSubview(versionLabel)
    
    addGestureRecognizer(
      UITapGestureRecognizer(
        target: self,
        action: #selector(didTap)
      )
    )
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    diamondView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      
      diamondView.widthAnchor.constraint(equalToConstant: 52).withPriority(.defaultHigh),
      diamondView.heightAnchor.constraint(equalToConstant: 52),
    ])
  }
  
  @objc func didTap() {
    diamondView.play()
  }
}

private extension String {
  static let diamondAnimationName = "diamond"
}
