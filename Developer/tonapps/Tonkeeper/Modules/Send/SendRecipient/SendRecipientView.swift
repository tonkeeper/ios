//
//  SendRecipientSendRecipientView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import UIKit

final class SendRecipientView: UIView {

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

private extension SendRecipientView {
  func setup() {
    backgroundColor = .Background.page
  }
}
