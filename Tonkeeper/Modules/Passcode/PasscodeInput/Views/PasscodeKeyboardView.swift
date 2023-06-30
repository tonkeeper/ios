//
//  PasscodeKeyboardView.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import UIKit

final class PasscodeKeyboardView: UIView {
  
  var didTapButton: ((PasscodeButton) -> Void)?
  
  let button0 = PasscodeButton(type: .digit(0))
  let button1 = PasscodeButton(type: .digit(1))
  let button2 = PasscodeButton(type: .digit(2))
  let button3 = PasscodeButton(type: .digit(3))
  let button4 = PasscodeButton(type: .digit(4))
  let button5 = PasscodeButton(type: .digit(5))
  let button6 = PasscodeButton(type: .digit(6))
  let button7 = PasscodeButton(type: .digit(7))
  let button8 = PasscodeButton(type: .digit(8))
  let button9 = PasscodeButton(type: .digit(9))
  let biometryButton = PasscodeButton(type: .biometry)
  let backspaceButton = PasscodeButton(type: .backspace)
  
  private lazy var buttons: [PasscodeButton] = {
    [button0, button1, button2, button3, button4, button5, button6,
     button7, button8, button9, biometryButton, backspaceButton]
  }()
  
  private lazy var stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.distribution = .fillEqually
    
    let firstRowStackView = UIStackView()
    firstRowStackView.axis = .horizontal
    firstRowStackView.distribution = .fillEqually
    
    let secondRowStackView = UIStackView()
    secondRowStackView.axis = .horizontal
    secondRowStackView.distribution = .fillEqually
    
    let thirdRowStackView = UIStackView()
    thirdRowStackView.axis = .horizontal
    thirdRowStackView.distribution = .fillEqually
    
    let fourthRowStackView = UIStackView()
    fourthRowStackView.axis = .horizontal
    fourthRowStackView.distribution = .fillEqually
    
    stackView.addArrangedSubview(firstRowStackView)
    stackView.addArrangedSubview(secondRowStackView)
    stackView.addArrangedSubview(thirdRowStackView)
    stackView.addArrangedSubview(fourthRowStackView)
    
    firstRowStackView.addArrangedSubview(button1)
    firstRowStackView.addArrangedSubview(button2)
    firstRowStackView.addArrangedSubview(button3)
    
    secondRowStackView.addArrangedSubview(button4)
    secondRowStackView.addArrangedSubview(button5)
    secondRowStackView.addArrangedSubview(button6)
    
    thirdRowStackView.addArrangedSubview(button7)
    thirdRowStackView.addArrangedSubview(button8)
    thirdRowStackView.addArrangedSubview(button9)
    
    fourthRowStackView.addArrangedSubview(biometryButton)
    fourthRowStackView.addArrangedSubview(button0)
    fourthRowStackView.addArrangedSubview(backspaceButton)
    
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
}

// MARK: - Private

private extension PasscodeKeyboardView {
  func setup() {
    addSubview(stackView)
    
    buttons.forEach {
      $0.addTarget(
        self,
        action: #selector(didTapButton(button:)),
        for: .touchUpInside
      )
    }
    
    setupConstraints()
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
  
  @objc
  func didTapButton(button: PasscodeButton) {
    didTapButton?(button)
  }
}
