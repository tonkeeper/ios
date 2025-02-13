import WebKit
import UIKit

public final class TKLottieWebView: UIView {
  private let webView = WKWebView()
  
  public override var backgroundColor: UIColor? {
    didSet {
      webView.backgroundColor = backgroundColor
      webView.scrollView.backgroundColor = backgroundColor
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    
    webView.isOpaque = false
    
    addSubview(webView)
    webView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: topAnchor),
      webView.leftAnchor.constraint(equalTo: leftAnchor),
      webView.bottomAnchor.constraint(equalTo: bottomAnchor),
      webView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
  
  public func loadLottieAnimation(url: URL) {
    loadLottieAnimation(url: url.absoluteString)
  }
  
  public func loadLottieAnimation(url: String) {
    copyLottieHTMLToTemporaryDirectoryIfNeeded()
    let lottieHTMLUrl = getLottieHTMLTemporaryDirectoryPath()
    var components = URLComponents(url: lottieHTMLUrl, resolvingAgainstBaseURL: true)
    components?.queryItems = [URLQueryItem(name: "url", value: url)]
    
    guard let resultURL = components?.url else { return }
    webView.load(URLRequest(url: resultURL))
  }
  
  private func copyLottieHTMLToTemporaryDirectoryIfNeeded() {
    guard let bundleLottieHTMLBundlePath = getLottieHTMLBundlePath() else { return }
    let lottieHTMLTemporaryDirectoryPath = getLottieHTMLTemporaryDirectoryPath()
    guard !FileManager.default.fileExists(atPath: lottieHTMLTemporaryDirectoryPath.path) else { return }
    try? FileManager.default.copyItem(at: bundleLottieHTMLBundlePath, to: lottieHTMLTemporaryDirectoryPath)
  }
  
  private func getLottieHTMLTemporaryDirectoryPath() -> URL {
    if #available(iOS 16.0, *) {
      return URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
        .appending(component: String.lottieWebviewFileName)
    } else {
      return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent(.lottieWebviewFileName)
    }
  }
  
  private func getLottieHTMLBundlePath() -> URL? {
    guard let url = Bundle.module.url(forResource: String.lottieWebviewFileName, withExtension: nil) else {
      return nil
    }
    return url
  }
}

private extension String {
  static let lottieWebviewFileName: String = "lottie-webview.html"
}
