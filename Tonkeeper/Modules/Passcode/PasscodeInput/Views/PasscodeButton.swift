//
//  PasscodeButton.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import UIKit

final class PasscodeButton: UIControlClosure {
  enum ButtonType {
    case digit(Int)
    case backspace
    case biometry
  }
  
  let type: ButtonType
  
  private let button = UIButton(type: .custom)
  private let hightlightView: UIView = {
    let view = UIView()
    view.backgroundColor = .Button.secondaryBackground
    view.alpha = 0
    view.transform = CGAffineTransform(
      scaleX: .notHighlightedScale,
      y: .notHighlightedScale
    )
    return view
  }()
  
  private var buttonIsHighlightedObservation: NSKeyValueObservation?
  
  init(type: ButtonType) {
    self.type = type
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override var intrinsicContentSize: CGSize {
    .init(width: UIView.noIntrinsicMetric, height: .buttonHeight)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    hightlightView.layoutIfNeeded()
    hightlightView.layer.cornerRadius = bounds.height/2
  }
}

private extension PasscodeButton {
  func setup() {
    button.titleLabel?.applyTextStyleFont(.num1)
    button.titleLabel?.textColor = .Text.primary
    button.titleLabel?.textAlignment = .center
    button.tintColor = .Icon.primary
    button.addTarget(
      self,
      action: #selector(didTapButton),
      for: .touchUpInside
    )
    
    addSubview(hightlightView)
    addSubview(button)
    
    switch type {
    case let .digit(digit):
      button.setTitle("\(digit)", for: .normal)
    case .backspace:
      button.setImage(.Icons.PasscodeButton.backspace, for: .normal)
    case .biometry:
      button.setImage(.Icons.PasscodeButton.biometry, for: .normal)
    }
    
    buttonIsHighlightedObservation = button.observe(\.isHighlighted, changeHandler: { [weak self] button, _ in
      self?.didUpdateIsHighlighted(button.isHighlighted)
    })
    
    setupConstraints()
  }
  
  func didUpdateIsHighlighted(_ isHighlighted: Bool) {
    let scale: CGFloat = isHighlighted ? 1 : .notHighlightedScale
    let alpha: CGFloat = isHighlighted ? 1 : 0
    let animation = {
      self.hightlightView.alpha = alpha
      self.hightlightView.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
    UIView.animate(withDuration: .animationDuration, delay: 0, options: [.curveEaseInOut]) {
      animation()
    }
  }
  
  func setupConstraints() {
    button.translatesAutoresizingMaskIntoConstraints = false
    hightlightView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      button.topAnchor.constraint(equalTo: topAnchor),
      button.leftAnchor.constraint(equalTo: leftAnchor),
      button.bottomAnchor.constraint(equalTo: bottomAnchor),
      button.rightAnchor.constraint(equalTo: rightAnchor),
      
      hightlightView.heightAnchor.constraint(equalTo: heightAnchor),
      hightlightView.widthAnchor.constraint(equalTo: heightAnchor),
      hightlightView.centerXAnchor.constraint(equalTo: centerXAnchor),
      hightlightView.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])
  }
  
  @objc
  func didTapButton() {
    sendActions(for: .touchUpInside)
  }
}

private extension CGFloat {
  static let buttonHeight: CGFloat = 72
  static let notHighlightedScale: CGFloat = 0.8
}

private extension TimeInterval {
  static let animationDuration: TimeInterval = 0.2
}
