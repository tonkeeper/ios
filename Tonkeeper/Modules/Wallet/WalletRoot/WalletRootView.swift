//
//  WalletRootView.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import UIKit

final class WalletRootView: UIView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension WalletRootView {
  func setup() {
    backgroundColor = .Background.page
  }
}
