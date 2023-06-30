//
//  PasscodeInputPasscodeInputView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/06/2023.
//

import UIKit

final class PasscodeInputView: UIView {
  
  let keyboardView = PasscodeKeyboardView()
  let dotRowView = PasscodeDotRowView()
  let titleLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.h3)
    label.textColor = .Text.primary
    label.textAlignment = .center
    return label
  }()
  
  private let topContentView = UIView()

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
    
    addSubview(topContentView)
    addSubview(keyboardView)
    topContentView.addSubview(dotRowView)
    topContentView.addSubview(titleLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    keyboardView.translatesAutoresizingMaskIntoConstraints = false
    topContentView.translatesAutoresizingMaskIntoConstraints = false
    dotRowView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      keyboardView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
      keyboardView.leftAnchor.constraint(equalTo: leftAnchor),
      keyboardView.rightAnchor.constraint(equalTo: rightAnchor),
      
      topContentView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      topContentView.leftAnchor.constraint(equalTo: leftAnchor),
      topContentView.rightAnchor.constraint(equalTo: rightAnchor),
      topContentView.bottomAnchor.constraint(equalTo: keyboardView.topAnchor),
      
      dotRowView.centerXAnchor.constraint(equalTo: topContentView.centerXAnchor),
      dotRowView.centerYAnchor.constraint(equalTo: topContentView.centerYAnchor),
      
      titleLabel.bottomAnchor.constraint(equalTo: dotRowView.topAnchor, constant: -.titleBottomSpace),
      titleLabel.leftAnchor.constraint(equalTo: leftAnchor),
      titleLabel.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}

private extension CGFloat {
  static let titleBottomSpace: CGFloat = 20
}
