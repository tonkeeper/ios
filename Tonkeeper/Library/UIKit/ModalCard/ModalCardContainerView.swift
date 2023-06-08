//
//  ModalCardContainerView.swift
//  Tonkeeper
//
//  Created by Grigory on 8.6.23..
//

import UIKit

final class ModalCardContainerView: PassthroughView {
  
  var maximumContentHeight: CGFloat {
    bounds.height
    - safeAreaInsets.top - safeAreaInsets.bottom
    - headerView.bounds.height
  }
  
  var contentHeight: CGFloat = 0 {
    didSet {
      contentContainerHeightConstraint?.constant = contentHeight
      mainViewHeightConstraint?.constant = contentHeight + 64
    }
  }
  
  var dragOffset: CGFloat = 0 {
    didSet {
      mainViewHeightConstraint?.constant = contentHeight - dragOffset + 64
      contentContainerHeightConstraint?.constant = contentHeight - dragOffset
    }
  }
  
  let contentContainer: UIView = {
    let view = UIView()
    view.backgroundColor = .brown
    return view
  }()
  
  let mainView: UIView = {
    let view = UIView()
    view.backgroundColor = .red
    return view
  }()
  
  let headerView: UIView = {
    let view = UIView()
    view.backgroundColor = .green
    return view
  }()
  
  var mainViewHeightConstraint: NSLayoutConstraint?
  var contentContainerHeightConstraint: NSLayoutConstraint?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func addContentView(_ view: UIView) {
    contentContainer.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
      view.leftAnchor.constraint(equalTo: contentContainer.leftAnchor),
      view.rightAnchor.constraint(equalTo: contentContainer.rightAnchor),
      view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
    ])
  }
}

private extension ModalCardContainerView {
  func setup() {
    addSubview(mainView)
    mainView.addSubview(headerView)
    mainView.addSubview(contentContainer)
    
    mainView.translatesAutoresizingMaskIntoConstraints = false
    headerView.translatesAutoresizingMaskIntoConstraints = false
    contentContainer.translatesAutoresizingMaskIntoConstraints = false
    
    mainViewHeightConstraint = mainView.heightAnchor.constraint(equalToConstant: 0)
    mainViewHeightConstraint?.isActive = true
    contentContainerHeightConstraint = contentContainer.heightAnchor.constraint(equalToConstant: 0)
    contentContainerHeightConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      mainView.bottomAnchor.constraint(equalTo: bottomAnchor),
      mainView.leftAnchor.constraint(equalTo: leftAnchor),
      mainView.rightAnchor.constraint(equalTo: rightAnchor),
      
      headerView.topAnchor.constraint(equalTo: mainView.topAnchor),
      headerView.leftAnchor.constraint(equalTo: mainView.leftAnchor),
      headerView.rightAnchor.constraint(equalTo: mainView.rightAnchor),
      headerView.heightAnchor.constraint(equalToConstant: 64),
      
      contentContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor),
      contentContainer.leftAnchor.constraint(equalTo: mainView.leftAnchor),
      contentContainer.rightAnchor.constraint(equalTo: mainView.rightAnchor)
    ])
  }
}
