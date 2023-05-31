//
//  SendRecipientSendRecipientView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import UIKit

final class SendRecipientView: UIView {
  
  let addressTextField = TextField()
  let commentTextField = TextField()

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
    
    addressTextField.isPasteButtonAvailable = true
    addressTextField.isScanQRCodeButtonAvailable = true
    
    addSubview(addressTextField)
    addSubview(commentTextField)
    
    addressTextField.translatesAutoresizingMaskIntoConstraints = false
    commentTextField.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      addressTextField.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      addressTextField.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      addressTextField.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace),
      
      commentTextField.topAnchor.constraint(equalTo: addressTextField.bottomAnchor, constant: .textFieldSpace),
      commentTextField.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      commentTextField.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace),
    ])
  }
}

private extension CGFloat {
  static let textFieldSpace: CGFloat = 16
}
