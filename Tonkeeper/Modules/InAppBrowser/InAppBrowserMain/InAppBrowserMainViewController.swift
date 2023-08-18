//
//  InAppBrowserMainInAppBrowserMainViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 18/08/2023.
//

import UIKit
import WebKit

class InAppBrowserMainViewController: GenericViewController<InAppBrowserMainView> {

  // MARK: - Module

  private let presenter: InAppBrowserMainPresenterInput
  
  // MARK: - State
  
  private var canGoBackObservation: NSKeyValueObservation?
  private var titleObservation: NSKeyValueObservation?
  private var urlObservation: NSKeyValueObservation?
  private var isLoadingObservation: NSKeyValueObservation?
  
  // MARK: - Refresh control
  
  private lazy var refreshControl: UIRefreshControl = {
    let refreshControl = UIRefreshControl()
    refreshControl.addTarget(
      self,
      action: #selector(didPullToRefresh),
      for: .valueChanged
    )
    refreshControl.tintColor = .white
    return refreshControl
  }()

  // MARK: - Init

  init(presenter: InAppBrowserMainPresenterInput) {
    self.presenter = presenter
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    presenter.viewDidLoad()
  }
}

// MARK: - InAppBrowserMainViewInput

extension InAppBrowserMainViewController: InAppBrowserMainViewInput {
  func loadURLRequest(_ urlRequest: URLRequest) {
    refreshControl.endRefreshing()
    customView.webView.load(urlRequest)
  }
  
  func showMenu(with items: [TKMenuItem]) {
    TKMenuController.show(sourceView: self.customView.headerView.twinButton,
                          position: .right,
                          width: .menuWidth,
                          items: items,
                          selectionClosure: { [weak self] in self?.presenter.didSelectMenuItem(at: $0) })
  }
  
  func shareURL(_ url: URL) {
    let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    activityViewController.overrideUserInterfaceStyle = .dark
    present(activityViewController, animated: true)
  }
}

// MARK: - Private

private extension InAppBrowserMainViewController {
  func setup() {
    customView.webView.scrollView.refreshControl = refreshControl
    
    canGoBackObservation = customView.webView.observe(\.canGoBack, options: .new) { [weak self] webView, _ in
      self?.customView.headerView.backButton.isHidden = !webView.canGoBack
    }
    
    titleObservation = customView.webView.observe(\.title, options: .new) { [weak self] webView, _ in
      self?.updateTitle(webView: webView)
      guard let url = webView.url else { return }
      self?.presenter.didChangeURL(url)
    }
    
    urlObservation = customView.webView.observe(\.url, options: .new) { [weak self] webView, _ in
      self?.updateTitle(webView: webView)
    }
  
    customView.headerView.didTapLeftTwinButton = { [presenter] in
      presenter.didTapMenuButton()
    }
    customView.headerView.didTapRightTwinButton = { [presenter] in
      presenter.didTapCloseButton()
    }
    customView.headerView.didTapBackButton = { [weak self] in
      self?.customView.webView.goBack()
    }
  }
  
  func updateTitle(webView: WKWebView) {
    var title: String = webView.title ?? "..."
    if title.isEmpty { title = "..." }
    customView.headerView.titleView.configure(model: .init(
      title: title,
      subtitle: createHeaderSubtitle(webView: webView))
    )
  }
  
  func createHeaderSubtitle(webView: WKWebView) -> NSAttributedString {
    let result = NSMutableAttributedString()
    if webView.serverTrust != nil,
       let sslIcon = UIImage.Icons.InAppBrowser.ssl {
      let attachment = NSTextAttachment(image: sslIcon)
      let attachmentString = NSMutableAttributedString(attachment: attachment)
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.alignment = .center
      
      let attributes: [NSAttributedString.Key: Any] = [
        .paragraphStyle: paragraphStyle,
        .foregroundColor: UIColor.Icon.tertiary,
        .baselineOffset: CGFloat.attachmentBaselineOffset,
      ]
      attachmentString.addAttributes(
        attributes,
        range: NSRange(location: 0, length: attachmentString.length))
      result.append(attachmentString)
    }
    guard let host = webView.url?.host else { return result }
    result.append(host.attributed(with: .body2, alignment: .center, color: .Text.secondary))

    return result
  }
  
  @objc
  func didPullToRefresh() {
    presenter.didPullToRefresh()
  }
}

private extension CGFloat {
  static let attachmentBaselineOffset: CGFloat = -2
  static let menuWidth: CGFloat = 196
}
