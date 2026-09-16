import TKAppInfo
import UIKit
import WebKit

public final class TKLottieWebView: UIView {
    private let webView: WKWebView
    public var onLoaded: (() -> Void)?
    public var onError: ((String) -> Void)?

    /// One page copy per instance. The shared path in `NSTemporaryDirectory()` used to be deleted
    /// and rewritten on every load, so two views loading at once could pull the file out from
    /// under each other.
    private let pageDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("TKLottieWebView-\(UUID().uuidString)", isDirectory: true)

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
        // `WKWebView` copies the configuration but shares its `userContentController`, which
        // retains message handlers strongly: registering `self` there is a retain cycle that
        // leaks the view along with its web content process.
        let messageHandler = WeakScriptMessageHandler()
        configuration.userContentController.add(messageHandler, name: .lottieEventsHandler)
        webView = WKWebView(frame: .zero, configuration: configuration)

        super.init(frame: frame)

        messageHandler.onMessage = { [weak self] body in
            self?.handleLottieEvent(body)
        }

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
        webView.configuration.userContentController
            .removeScriptMessageHandler(forName: .lottieEventsHandler)
        try? FileManager.default.removeItem(at: pageDirectory)
    }

    public func loadLottieAnimation(url: URL) {
        loadLottieAnimation(url: url.absoluteString)
    }

    public func loadLottieAnimation(url: String) {
        guard let pageURL = preparePage() else { return }
        var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "url", value: url)]

        guard let resultURL = components?.url else { return }
        webView.load(URLRequest(url: resultURL))
    }

    private func preparePage() -> URL? {
        guard let bundled = Bundle.module.url(forResource: .lottieWebviewFileName, withExtension: nil) else {
            return nil
        }
        let destination = pageDirectory.appendingPathComponent(.lottieWebviewFileName)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return destination }
        do {
            try FileManager.default.createDirectory(at: pageDirectory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: bundled, to: destination)
        } catch {
            return nil
        }
        return destination
    }

    private func handleLottieEvent(_ body: Any) {
        guard let dict = body as? [String: Any] else { return }
        switch dict["type"] as? String {
        case "loaded":
            onLoaded?()
        case "error":
            onError?(dict["message"] as? String ?? "Unknown error")
        default:
            break
        }
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    var onMessage: ((Any) -> Void)?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == .lottieEventsHandler else { return }
        onMessage?(message.body)
    }
}

private extension String {
    static let lottieWebviewFileName = "lottie-webview.html"
    static let lottieEventsHandler = "lottieEvents"
}
