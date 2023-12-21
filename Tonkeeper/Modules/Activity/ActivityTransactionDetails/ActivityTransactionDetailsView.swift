//
//  ActivityTransactionDetailsActivityTransactionDetailsView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import UIKit

final class ActivityTransactionDetailsView: UIView {
  
  let openTransactionButton = TKButtonControl(buttonContent: OpenTransactionTKButtonContentView(),
                                              buttonCategory: .secondary,
                                              buttonSize: .small)
  
  private let modalContentContainer = UIView()

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Content
  
  func embedContent(_ view: UIView) {
    modalContentContainer.addSubview(view)
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: modalContentContainer.topAnchor),
      view.leftAnchor.constraint(equalTo: modalContentContainer.leftAnchor),
      view.bottomAnchor.constraint(equalTo: modalContentContainer.bottomAnchor),
      view.rightAnchor.constraint(equalTo: modalContentContainer.rightAnchor)
    ])
  }
}

// MARK: - Private

private extension ActivityTransactionDetailsView {
  func setup() {
    addSubview(modalContentContainer)
    addSubview(openTransactionButton)
    
    modalContentContainer.translatesAutoresizingMaskIntoConstraints = false
    openTransactionButton.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      modalContentContainer.topAnchor.constraint(equalTo: topAnchor),
      modalContentContainer.leftAnchor.constraint(equalTo: leftAnchor),
      modalContentContainer.rightAnchor.constraint(equalTo: rightAnchor),
      
      openTransactionButton.topAnchor.constraint(equalTo: modalContentContainer.bottomAnchor),
      openTransactionButton.centerXAnchor.constraint(equalTo: centerXAnchor),
      openTransactionButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -32).withPriority(.defaultHigh)
    ])
  }
}
