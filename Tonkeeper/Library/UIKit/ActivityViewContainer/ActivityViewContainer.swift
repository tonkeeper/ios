//
//  ActivityViewContainer.swift
//  Tonkeeper
//
//  Created by Grigory on 7.7.23..
//

import UIKit

protocol ActivityViewContainerView: UIView {
  var loaderViewColor: UIColor { get }
  func showActivity()
  func hideActivity()
}

final class ActivityViewContainer: UIView {
  
  private let view: ActivityViewContainerView
  private lazy var loadingView: LoaderView = {
    let loaderView = LoaderView(size: .medium)
    loaderView.color = view.loaderViewColor
    loaderView.isHidden = true
    return loaderView
  }()
  
  init(view: ActivityViewContainerView) {
    self.view = view
    super.init(frame: .zero)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func showActivity() {
    view.showActivity()
    loadingView.isHidden = false
    loadingView.startAnimation()
  }
  
  func hideActivity() {
    view.hideActivity()
    loadingView.isHidden = true
    loadingView.stopAnimation()
  }
}

private extension ActivityViewContainer {
  func setup() {
    addSubview(view)
    addSubview(loadingView)
    
    view.translatesAutoresizingMaskIntoConstraints = false
    loadingView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: topAnchor),
      view.leftAnchor.constraint(equalTo: leftAnchor),
      view.rightAnchor.constraint(equalTo: rightAnchor),
      view.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      loadingView.topAnchor.constraint(equalTo: topAnchor),
      loadingView.leftAnchor.constraint(equalTo: leftAnchor),
      loadingView.rightAnchor.constraint(equalTo: rightAnchor),
      loadingView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}
