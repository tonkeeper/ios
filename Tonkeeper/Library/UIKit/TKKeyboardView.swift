//
//  TKKeyboardView.swift
//  Tonkeeper
//
//  Created by Grigory on 21.7.23..
//

import UIKit

protocol TKKeyboardViewDelegate: AnyObject {
  func keyboard(_ keyboard: TKKeyboardView, didTapDigit digit: Int)
  func keyboardDidTapBackspace(_ keyboard: TKKeyboardView)
}

protocol TKKeyboardViewBiometryDelegate: TKKeyboardViewDelegate {
  func keyboardDidTapBiometry(_ keyboard: TKKeyboardView)
}

protocol TKKeyboardViewFractionalDelegate: TKKeyboardViewDelegate {
  func keyboard(_ keyboard: TKKeyboardView, didTapDecimalSeparator separator: String)
}

final class TKKeyboardView: UIView {
  
  weak var delegate: TKKeyboardViewDelegate?
  
  var size: TKKeyboardButton.Size = .big {
    didSet {
      configuration.buttons.forEach { $0.size = size }
    }
  }

  private let configuration: TKKeyboardConfiguration
  private let stackView = UIStackView()
  
  // MARK: - Init
  
  init(configuration: TKKeyboardConfiguration) {
    self.configuration = configuration
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Private

private extension TKKeyboardView {
  func setup() {
    addSubview(stackView)
    
    setupConstraints()
    createButtonRowsStackViews()
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
  
  func createButtonRowsStackViews() {
    let buttons = configuration.buttons
    
    stackView.axis = .vertical
    stackView.distribution = .fillEqually
    
    let buttonsRows = stride(from: 0, to: buttons.count, by: 3)
      .map { Array(buttons[$0 ..< min($0+3, buttons.count)]) }
    
    for row in buttonsRows {
      let rowStackView = UIStackView()
      rowStackView.axis = .horizontal
      rowStackView.distribution = .fillEqually
      
      for button in row {
        rowStackView.addArrangedSubview(button)
        button.addTarget(self, action: #selector(didTapButton(button:)), for: .touchUpInside)
      }
      
      stackView.addArrangedSubview(rowStackView)
    }
  }
  
  @objc
  func didTapButton(button: TKKeyboardButton) {
    switch button.buttonType {
    case .backspace:
      delegate?.keyboardDidTapBackspace(self)
    case .biometry:
      (delegate as? TKKeyboardViewBiometryDelegate)?.keyboardDidTapBiometry(self)
    case .decimalSeparator:
      (delegate as? TKKeyboardViewFractionalDelegate)?.keyboard(self, didTapDecimalSeparator: Locale.current.decimalSeparator ?? ".")
    case .digit(let digit):
      delegate?.keyboard(self, didTapDigit: digit)
    }
  }
}

