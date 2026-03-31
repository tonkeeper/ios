import KeeperCore
import os
import SnapKit
import TKCore
import TKLogging
import TKScreenKit
import TKUIKit
import UIKit

final class DappViewController: UIViewController {
    private let viewModel: DappViewModel

    private var bridgeWebViewController: TKBridgeWebViewController?
    private let deeplinkHandler: (_ deeplink: Deeplink) -> Void
    private let logger: Logger

    init(
        viewModel: DappViewModel,
        logger: Logger,
        deeplinkHandler: @escaping (_ deeplink: Deeplink) -> Void
    ) {
        self.viewModel = viewModel
        self.deeplinkHandler = deeplinkHandler
        self.logger = logger
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBinding()
        viewModel.viewDidLoad()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if viewModel.isLandscapeEnable {
            return .allButUpsideDown
        } else {
            return .portrait
        }
    }

    override var shouldAutorotate: Bool {
        viewModel.isLandscapeEnable
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        TKPopupMenuController.dismiss()
    }
}

private extension DappViewController {
    func setupBinding() {
        viewModel.didOpenApp = { [weak self] url, title in
            guard let self, let url else { return }

            let controllerConfiguration: TKBridgeWebViewController.Configuration
            do {
                controllerConfiguration = try .dapp(walletIdentifier: viewModel.walletIdentifier)
            } catch {
                logger.warning("failed to create webview configuration for wallet due to error: \(error)")
                controllerConfiguration = .default
            }
            let bridgeWebViewController = TKBridgeWebViewController(
                initialURL: url,
                copyURL: url,
                initialTitle: title,
                jsInjection: self.viewModel.jsInjection,
                configuration: controllerConfiguration,
                deeplinkHandler: { [weak self] url in
                    guard let self else {
                        return
                    }
                    let deeplinkParser = DeeplinkParser()
                    let deeplink = try deeplinkParser.parse(string: url)
                    self.deeplinkHandler(deeplink)
                },
                customizeWebView: { [weak self] webView in
                    self?.viewModel.webViewCustomizationHandler?(webView)
                }
            )
            bridgeWebViewController.didLoadInitialURLHandler = { [weak self] in
                self?.viewModel.didLoadInitialRequest()
            }
            self.addChild(bridgeWebViewController)
            self.view.addSubview(bridgeWebViewController.view)
            bridgeWebViewController.didMove(toParent: self)

            bridgeWebViewController.view.snp.makeConstraints { make in
                make.edges.equalTo(self.view)
            }
            bridgeWebViewController.addBridgeMessageObserver(message: "dapp", observer: { [weak self] body in
                self?.viewModel.didReceiveMessage(body: body)
            })
            bridgeWebViewController.didTapCopy = { [weak self] url in
                self?.viewModel.copyDappURL(url: url)
            }

            bridgeWebViewController.didTapShare = { [weak self] url in
                self?.viewModel.shareDappURL(url: url)
            }

            self.bridgeWebViewController = bridgeWebViewController
        }

        viewModel.injectHandler = { [weak self] jsInjection in
            Task {
                do {
                    try await self?.bridgeWebViewController?.evaulateJavaScript(jsInjection)
                } catch {
                    Log.e("dapp injectHandler: failed to evaluate js", extraInfo: [
                        "error": error.localizedDescription,
                    ])
                }
            }
        }

        viewModel.didUpdateIsLandscapeEnable = { [weak self] in
            if #available(iOS 16.0, *) {
                self?.setNeedsUpdateOfSupportedInterfaceOrientations()
            } else {
                UIViewController.attemptRotationToDeviceOrientation()
            }
        }

        viewModel.didShareURLSystemShareSheet = { [weak self] url in
            let activityViewController = UIActivityViewController(
                activityItems: [url as Any],
                applicationActivities: nil
            )
            self?.present(
                activityViewController,
                animated: true
            )
        }
    }
}
