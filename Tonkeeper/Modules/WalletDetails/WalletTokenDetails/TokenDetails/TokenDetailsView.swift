//
//  TokenDetailsTokenDetailsView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 13/07/2023.
//

import UIKit

final class TokenDetailsView: UIView {
  
  let listContainer = UIView()
  let refreshControl = UIRefreshControl()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Embed
  
  func embedListView(_ listView: UIView) {
    listContainer.addSubview(listView)
    listView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      listView.topAnchor.constraint(equalTo: listContainer.topAnchor),
      listView.leftAnchor.constraint(equalTo: listContainer.leftAnchor),
      listView.rightAnchor.constraint(equalTo: listContainer.rightAnchor),
      listView.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor)
    ])
  }
}

// MARK: - Private

private extension TokenDetailsView {
  func setup() {
    addSubview(listContainer)
    setupConstraints()
  }
  
  func setupConstraints() {
    listContainer.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      listContainer.topAnchor.constraint(equalTo: topAnchor),
      listContainer.leftAnchor.constraint(equalTo: leftAnchor),
      listContainer.rightAnchor.constraint(equalTo: rightAnchor),
      listContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
}
