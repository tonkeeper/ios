//
//  SendAmountSendAmountView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import UIKit

final class SendAmountView: UIView {
  
  let continueButton: TKButton = {
    let button = TKButton(configuration: .primaryLarge)
    button.titleLabel.text = "Continue"
    return button
  }()
  
  lazy var continueButtonActivityContainer: ActivityViewContainer = {
    .init(view: continueButton)
  }()

  private let contentView = UIView()
  private let enterAmountContainer = UIView()
  
  let keyboardView = TKKeyboardView(configuration: TKKeyboardDecimalAmountConfiguration())
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Embed
  
  func embedEnterAmountView(_ enterAmountView: UIView) {
    enterAmountContainer.addSubview(enterAmountView)
    enterAmountView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      enterAmountView.topAnchor.constraint(equalTo: enterAmountContainer.topAnchor),
      enterAmountView.leftAnchor.constraint(equalTo: enterAmountContainer.leftAnchor),
      enterAmountView.rightAnchor.constraint(equalTo: enterAmountContainer.rightAnchor)
        .withPriority(.defaultHigh),
      enterAmountView.bottomAnchor.constraint(equalTo: enterAmountContainer.bottomAnchor)
        .withPriority(.defaultHigh)
    ])
  }
}

// MARK: - Private

private extension SendAmountView {
  func setup() {
    backgroundColor = .Background.page
    
    keyboardView.size = .small
    
    addSubview(contentView)
    contentView.addSubview(enterAmountContainer)
    contentView.addSubview(continueButtonActivityContainer)
    addSubview(keyboardView)
    
    contentView.translatesAutoresizingMaskIntoConstraints = false
    enterAmountContainer.translatesAutoresizingMaskIntoConstraints = false
    continueButtonActivityContainer.translatesAutoresizingMaskIntoConstraints = false
    keyboardView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 4),
      contentView.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      contentView.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace)
        .withPriority(.defaultHigh),
      contentView.bottomAnchor.constraint(equalTo: keyboardView.topAnchor, constant: -.keyboardTopSpace),
      
      enterAmountContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
      enterAmountContainer.leftAnchor.constraint(equalTo: contentView.leftAnchor),
      enterAmountContainer.rightAnchor.constraint(equalTo: contentView.rightAnchor)
        .withPriority(.defaultHigh),
      
      continueButtonActivityContainer.topAnchor.constraint(equalTo: enterAmountContainer.bottomAnchor),
      continueButtonActivityContainer.leftAnchor.constraint(equalTo: contentView.leftAnchor),
      continueButtonActivityContainer.rightAnchor.constraint(equalTo: contentView.rightAnchor)
        .withPriority(.defaultHigh),
      continueButtonActivityContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        .withPriority(.defaultHigh),
      
      keyboardView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -.keyboardBottomSpace)
        .withPriority(.defaultHigh),
      keyboardView.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      keyboardView.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace)
        .withPriority(.defaultHigh)
    ])
  }
}

private extension CGFloat {
  static let keyboardBottomSpace: CGFloat = 25
  static let keyboardTopSpace: CGFloat = 20
}
