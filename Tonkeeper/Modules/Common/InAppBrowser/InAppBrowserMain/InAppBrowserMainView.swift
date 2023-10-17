//
//  InAppBrowserMainInAppBrowserMainView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 18/08/2023.
//

import UIKit
import WebKit

final class InAppBrowserMainView: UIView {
  
  let headerView = InAppBrowserMainHeaderView()
  let webView = WKWebView()

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

private extension InAppBrowserMainView {
  func setup() {
    backgroundColor = .Background.page
    webView.scrollView.backgroundColor = .Background.page
    
    addSubview(headerView)
    addSubview(webView)
    
    headerView.twinButton.configure(model: .init(
                leftButtonModel: .init(icon: .Icons.Buttons.Header.more),
                rightButtonModel: .init(icon: .Icons.Buttons.Header.close))
    )
    
    headerView.backButton.configure(model: .init(icon: .Icons.Buttons.Header.back))
    
    setupConstraints()
  }
  
  func setupConstraints() {
    headerView.translatesAutoresizingMaskIntoConstraints = false
    webView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      headerView.topAnchor.constraint(equalTo: topAnchor),
      headerView.leftAnchor.constraint(equalTo: leftAnchor),
      headerView.rightAnchor.constraint(equalTo: rightAnchor),
      
      webView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
      webView.leftAnchor.constraint(equalTo: leftAnchor),
      webView.rightAnchor.constraint(equalTo: rightAnchor),
      webView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}
