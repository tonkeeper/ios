//
//  ActivityRootActivityRootView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import UIKit

final class ActivityRootView: UIView {
  
  private let emptyContainer = UIView()
  private let listContainer = UIView()

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
    listContainer.isHidden = true
  }
  
  func showList() {
    listContainer.isHidden = false
    emptyContainer.isHidden = true
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
  
  func addListContentView(view: UIView) {
    listContainer.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: listContainer.topAnchor),
      view.leftAnchor.constraint(equalTo: listContainer.leftAnchor),
      view.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor),
      view.rightAnchor.constraint(equalTo: listContainer.rightAnchor)
    ])
  }
}

// MARK: - Private

private extension ActivityRootView {
  func setup() {
    addSubview(emptyContainer)
    addSubview(listContainer)
    
    emptyContainer.translatesAutoresizingMaskIntoConstraints = false
    listContainer.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      emptyContainer.topAnchor.constraint(equalTo: topAnchor),
      emptyContainer.leftAnchor.constraint(equalTo: leftAnchor),
      emptyContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
      emptyContainer.rightAnchor.constraint(equalTo: rightAnchor),
      
      listContainer.topAnchor.constraint(equalTo: topAnchor),
      listContainer.leftAnchor.constraint(equalTo: leftAnchor),
      listContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
      listContainer.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
