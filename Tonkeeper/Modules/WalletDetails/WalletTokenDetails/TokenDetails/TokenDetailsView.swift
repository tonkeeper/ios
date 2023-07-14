//
//  TokenDetailsTokenDetailsView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 13/07/2023.
//

import UIKit

final class TokenDetailsView: UIView {
  
  let scrollView = UIScrollView()
  let headerView = TokenDetailsHeaderView()
  let refreshControl = UIRefreshControl()

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

private extension TokenDetailsView {
  func setup() {
    refreshControl.tintColor = .Icon.primary
    
    scrollView.alwaysBounceVertical = true
    scrollView.refreshControl = refreshControl
    
    addSubview(scrollView)
    scrollView.addSubview(headerView)
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    headerView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      headerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      headerView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      headerView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      headerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      headerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
    ])
  }
}
