import TKAppInfo
import UIKit
import WebKit

public final class TKLottieWebView: UIView {
    private let webView: WKWebView
    public var onLoaded: (() -> Void)?
    public var onError: ((String) -> Void)?

    override public var backgroundColor: UIColor? {
        didSet {
            webView.backgroundColor = backgroundColor
            webView.scrollView.backgroundColor = backgroundColor
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public init(frame: CGRect) {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)

        super.init(frame: frame)

        configuration.userContentController.add(self, name: "lottieEvents")

        webView.isOpaque = false
        if #available(iOS 16.4, *), !UIApplication.shared.isAppStoreEnvironment {
            webView.isInspectable = true
        }

        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leftAnchor.constraint(equalTo: leftAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.rightAnchor.constraint(equalTo: rightAnchor),
        ])
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "lottieEvents")
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
        if FileManager.default.fileExists(atPath: lottieHTMLTemporaryDirectoryPath.path) {
            try? FileManager.default.removeItem(at: lottieHTMLTemporaryDirectoryPath)
        }
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

extension TKLottieWebView: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "lottieEvents" else { return }
        if let dict = message.body as? [String: Any] {
            let type = dict["type"] as? String
            let msg = dict["message"] as? String
            switch type {
            case "loaded":
                onLoaded?()
            case "error":
                onError?(msg ?? "Unknown error")
            default:
                break
            }
        }
    }
}
