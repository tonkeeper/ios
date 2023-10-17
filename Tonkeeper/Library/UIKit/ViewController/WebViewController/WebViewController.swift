//
//  WebViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 16.10.23..
//

import UIKit
import TKUIKit
import WebKit

final class WebViewController: UIViewController {
  private let webView = WKWebView()
  
  private let url: URL
  
  init(url: URL) {
    self.url = url
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(webView)
    view.backgroundColor = .Background.page
    webView.backgroundColor = .Background.page
    webView.scrollView.backgroundColor = .Background.page
    webView.load(URLRequest(url: url))
    setupCloseRightButton { [weak self] in
      self?.dismiss(animated: true)
    }
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    webView.frame = view.bounds
  }
}
