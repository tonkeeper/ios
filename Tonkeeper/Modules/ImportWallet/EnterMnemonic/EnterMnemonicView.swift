//
//  EnterMnemonicEnterMnemonicView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import UIKit

final class EnterMnemonicView: UIView {

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

private extension EnterMnemonicView {
  func setup() {
    backgroundColor = .Background.page
  }
}
