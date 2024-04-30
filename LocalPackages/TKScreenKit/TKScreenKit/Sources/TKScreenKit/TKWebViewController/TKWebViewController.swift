import UIKit
import TKUIKit
import WebKit

public final class TKWebViewController: UIViewController {
  private let webView = WKWebView()
  
  private let url: URL
  
  public init(url: URL) {
    self.url = url
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(webView)
    view.backgroundColor = .Background.page
    webView.backgroundColor = .Background.page
    webView.scrollView.backgroundColor = .Background.page
    webView.load(URLRequest(url: url))
    setupRightCloseButton { [weak self] in
      self?.dismiss(animated: true)
    }
  }
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    webView.frame = view.bounds
  }
}
