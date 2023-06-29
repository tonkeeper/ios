//
//  PasscodeInputPasscodeInputView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/06/2023.
//

import UIKit

final class PasscodeInputView: UIView {

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
  }
}
