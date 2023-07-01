//
//  PasscodeDotRowView.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import UIKit

final class PasscodeDotRowView: UIView {
  
  enum InputState {
    case input(count: Int)
  }
  
  enum ValidationState {
    case none
    case success
    case failed
  }
  
  var inputState: InputState = .input(count: 0) {
    didSet {
      updateStateAppearance()
    }
  }
  
  var validationState: ValidationState = .none {
    didSet {
      updateStateAppearance()
    }
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .fillEqually
    stackView.spacing = .interDotSpace
    return stackView
  }()
  
  private(set) var dots = [PasscodeDotView]()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension PasscodeDotRowView {
  func setup() {
    
    (0..<4).forEach { _ in
      let dotView = PasscodeDotView()
      dots.append(dotView)
      stackView.addArrangedSubview(dotView)
    }
    
    addSubview(stackView)
    
    setupConstraints()
    
    updateStateAppearance()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
  
  func updateStateAppearance() {
    switch inputState {
    case let .input(count):
      dots.enumerated().forEach {
        if $0 > count - 1 {
          $1.state = .empty
        } else {
          let dotState: PasscodeDotView.State
          switch validationState {
          case .none:
            dotState = .filled
          case .success:
            dotState = .success
          case .failed:
            dotState = .failed
          }
          $1.state = dotState
        }
      }
    }
  }
}

private extension CGFloat {
  static let side: CGFloat = 12
  static let bigSide: CGFloat = 16
  static let interDotSpace: CGFloat = 16
}

