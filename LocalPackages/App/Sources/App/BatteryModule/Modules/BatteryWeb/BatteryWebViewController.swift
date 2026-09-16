import SnapKit
import TKLogging
import TKScreenKit
import TKUIKit
import UIKit

final class BatteryWebViewController: UIViewController {
    private let viewModel: BatteryWebViewModel

    private var bridgeWebViewController: TKBridgeWebViewController?

    init(viewModel: BatteryWebViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .Background.page
        setupBinding()
        viewModel.viewDidLoad()
    }
}

private extension BatteryWebViewController {
    func setupBinding() {
        viewModel.didOpen = { [weak self] url, title in
            guard let self else { return }

            let configuration: TKBridgeWebViewController.Configuration
            do {
                configuration = try .dapp(walletIdentifier: viewModel.walletIdentifier)
            } catch {
                Log.w("battery web: failed to create webview configuration for wallet", error: error)
                configuration = .default
            }

            let bridgeWebViewController = TKBridgeWebViewController(
                initialURL: url,
                copyURL: url,
                initialTitle: title,
                jsInjection: viewModel.jsInjection,
                configuration: configuration
            )
            addChild(bridgeWebViewController)
            view.addSubview(bridgeWebViewController.view)
            bridgeWebViewController.didMove(toParent: self)

            bridgeWebViewController.view.snp.makeConstraints { make in
                make.edges.equalTo(self.view)
            }
            bridgeWebViewController.addBridgeMessageObserver(
                message: BatteryWebBridge.messageHandlerName,
                observer: { [weak self, weak bridgeWebViewController] body in
                    self?.viewModel.didReceiveMessage(body: body, pageURL: bridgeWebViewController?.currentURL)
                }
            )

            self.bridgeWebViewController = bridgeWebViewController
        }

        viewModel.injectHandler = { [weak self] js, trustedURL in
            Task { @MainActor in
                guard let bridgeWebViewController = self?.bridgeWebViewController else {
                    return
                }
                guard BatteryWebBridge.isTrustedOrigin(
                    pageURL: bridgeWebViewController.currentURL,
                    startURL: trustedURL
                ) else {
                    Log.w("battery web injectHandler: response rejected: untrusted page", extraInfo: [
                        "host": bridgeWebViewController.currentURL?.host ?? "",
                    ])
                    return
                }
                do {
                    try await bridgeWebViewController.evaulateJavaScript(js)
                } catch {
                    Log.e("battery web injectHandler: failed to evaluate js", error: error)
                }
            }
        }
    }
}
