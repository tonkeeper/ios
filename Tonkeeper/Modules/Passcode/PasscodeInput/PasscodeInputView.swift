//
//  PasscodeInputPasscodeInputView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/06/2023.
//

import UIKit

final class PasscodeInputView: UIView {
  
  let keyboardView = PasscodeKeyboardView()

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

private extension PasscodeInputView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(keyboardView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    keyboardView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      keyboardView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
      keyboardView.leftAnchor.constraint(equalTo: leftAnchor),
      keyboardView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
