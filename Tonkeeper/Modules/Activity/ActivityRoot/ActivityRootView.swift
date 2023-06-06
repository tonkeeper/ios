//
//  ActivityRootActivityRootView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import UIKit

final class ActivityRootView: UIView {
  
  private let emptyContainer = UIView()

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Content
  
  func showEmptyState() {
    emptyContainer.isHidden = false
  }
  
  func addEmptyContentView(view: UIView) {
    emptyContainer.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: emptyContainer.topAnchor),
      view.leftAnchor.constraint(equalTo: emptyContainer.leftAnchor),
      view.bottomAnchor.constraint(equalTo: emptyContainer.bottomAnchor),
      view.rightAnchor.constraint(equalTo: emptyContainer.rightAnchor)
    ])
  }
}

// MARK: - Private

private extension ActivityRootView {
  func setup() {
    addSubview(emptyContainer)
    
    emptyContainer.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      emptyContainer.topAnchor.constraint(equalTo: topAnchor),
      emptyContainer.leftAnchor.constraint(equalTo: leftAnchor),
      emptyContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
      emptyContainer.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
