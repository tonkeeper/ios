import KeeperCore
import SnapKit
import TKCore
import TKLogging
import TKScreenKit
import TKUIKit
import UIKit

final class DappViewController: UIViewController, TKEdgeSwipeBackOnly {
    private static let headerFallbackTimeout: TimeInterval = 15

    private let viewModel: DappViewModel

    private var bridgeWebViewController: TKBridgeWebViewController?
    var currentURL: URL? {
        bridgeWebViewController?.currentURL
    }

    var didPop: ((_ byGesture: Bool) -> Void)?
    var didDismiss: (() -> Void)?

    private var headerFallbackWorkItem: DispatchWorkItem?
    private var wasNavigationBarHidden: Bool?
    private var isHeaderForced = false
    private var isDisappearingByGesture = false

    private var isSwipeBackEnabled: Bool {
        viewModel.allowsBackForwardNavigationGestures && !(bridgeWebViewController?.canGoBack ?? false)
    }

    private let deeplinkHandler: (_ deeplink: Deeplink, _ utm: UtmParameters) -> Void
    private let deeplinkParser: DeeplinkParser

    init(
        viewModel: DappViewModel,
        deeplinkHandler: @escaping (_ deeplink: Deeplink, _ utm: UtmParameters) -> Void,
        deeplinkParser: DeeplinkParser
    ) {
        self.viewModel = viewModel
        self.deeplinkHandler = deeplinkHandler
        self.deeplinkParser = deeplinkParser
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBinding()
        observeUserInterfaceStyle()
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Under liquid glass the page header is the stack's system bar, which the header shows, hides and
        // hands back to the stack.
        if !TKLiquidGlass.isEnabled {
            if wasNavigationBarHidden == nil {
                wasNavigationBarHidden = navigationController?.isNavigationBarHidden
            }
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
        navigationController?.interactivePopGestureRecognizer?.isEnabled = isSwipeBackEnabled
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isDisappearingByGesture = isMovingFromParent && transitionCoordinator?.initiallyInteractive == true
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        if let wasNavigationBarHidden {
            navigationController?.setNavigationBarHidden(wasNavigationBarHidden, animated: animated)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            didDismiss?()
        }
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            didPop?(isDisappearingByGesture)
        }
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        if #unavailable(iOS 17.0) {
            viewModel.didChangeSystemAppearance()
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if viewModel.isLandscapeEnable {
            return UIInterfaceOrientationMask.tkDefault.union(.allButUpsideDown)
        } else {
            return .tkDefault
        }
    }

    override var shouldAutorotate: Bool {
        viewModel.isLandscapeEnable || UIInterfaceOrientationMask.tkDefault != .portrait
    }
}

private extension DappViewController {
    func observeUserInterfaceStyle() {
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
                self.viewModel.didChangeSystemAppearance()
            }
        }
    }

    func scheduleHeaderFallback() {
        cancelHeaderFallback()
        let workItem = DispatchWorkItem { [weak self] in
            self?.forceHeaderVisible()
        }
        headerFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.headerFallbackTimeout, execute: workItem)
    }

    func cancelHeaderFallback() {
        headerFallbackWorkItem?.cancel()
        headerFallbackWorkItem = nil
    }

    func forceHeaderVisible() {
        cancelHeaderFallback()
        isHeaderForced = true
        bridgeWebViewController?.isHeaderHidden = false
    }

    func endHeaderFallback(for url: URL) {
        cancelHeaderFallback()
        isHeaderForced = false
        applyHeaderVisibility(for: url)
    }

    func applyHeaderVisibility(for url: URL) {
        guard !isHeaderForced else { return }
        bridgeWebViewController?.isHeaderHidden = viewModel.isNativeHeaderHidden(for: url)
    }

    func injectKeeperBridgeResponse(_ js: String, containsCredentials: Bool) async {
        guard let bridgeWebViewController else { return }
        guard !containsCredentials || KeeperDappBridge.isTrusted(url: bridgeWebViewController.currentURL) else {
            Log.w("keeper dapp bridge: response rejected: untrusted page", extraInfo: [
                "host": bridgeWebViewController.currentURL?.host ?? "",
            ])
            return
        }
        do {
            try await bridgeWebViewController.evaulateJavaScript(js)
        } catch {
            Log.e("keeper dapp bridge: failed to evaluate js", error: error)
        }
    }

    func setupBinding() {
        viewModel.didOpenApp = { [weak self] url, title in
            guard let self, let url else { return }

            let applicationNameForUserAgent = viewModel.applicationNameForUserAgent
            let allowsBackForwardNavigationGestures = viewModel.allowsBackForwardNavigationGestures
            let controllerConfiguration: TKBridgeWebViewController.Configuration
            do {
                controllerConfiguration = try .dapp(
                    walletIdentifier: viewModel.walletIdentifier,
                    applicationNameForUserAgent: applicationNameForUserAgent,
                    showsInitialLoadingIndicator: true,
                    allowsBackForwardNavigationGestures: allowsBackForwardNavigationGestures
                )
            } catch {
                Log.w("failed to create webview configuration for wallet", error: error)
                controllerConfiguration = TKBridgeWebViewController.Configuration(
                    copyToastConfiguration: .copied,
                    applicationNameForUserAgent: applicationNameForUserAgent,
                    showsInitialLoadingIndicator: true,
                    allowsBackForwardNavigationGestures: allowsBackForwardNavigationGestures
                )
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
                    do {
                        let deeplink = try deeplinkParser.parse(
                            string: url,
                            source: .dapp
                        )
                        self.deeplinkHandler(deeplink, UtmParameters(link: url))
                    } catch let error as DeeplinkParserError where error.isSilent {
                        return
                    } catch {
                        throw error
                    }
                }
            )
            bridgeWebViewController.isHeaderHidden = viewModel.isNativeHeaderHidden(for: url)
            bridgeWebViewController.showsCloseButtonWhenHeaderHidden = viewModel.isKeeperBridgeEnabled
            if bridgeWebViewController.isHeaderHidden, !viewModel.isKeeperBridgeEnabled {
                scheduleHeaderFallback()
            }
            bridgeWebViewController.didLoadInitialURLHandler = { [weak self] in
                self?.viewModel.didLoadInitialRequest()
            }
            bridgeWebViewController.didCommitLoad = { [weak self] url in
                self?.viewModel.didCommitLoad()
                self?.applyHeaderVisibility(for: url)
            }
            bridgeWebViewController.didFinishLoad = { [weak self] url in
                self?.endHeaderFallback(for: url)
            }
            bridgeWebViewController.didFailLoad = { [weak self, weak bridgeWebViewController] failure, isPageShown in
                guard let self, let bridgeWebViewController else { return }
                let pageURL = bridgeWebViewController.currentURL ?? url
                endHeaderFallback(for: pageURL)
                if viewModel.showsLoadFailurePlaceholder(for: failure, at: pageURL, isPageShown: isPageShown) {
                    bridgeWebViewController.showLoadFailurePlaceholder()
                }
                viewModel.didFailLoad(failure)
            }
            bridgeWebViewController.didChangeCanGoBack = { [weak self] _ in
                guard let self, navigationController?.topViewController === self else { return }
                navigationController?.interactivePopGestureRecognizer?.isEnabled = isSwipeBackEnabled
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
            if viewModel.isKeeperBridgeEnabled {
                bridgeWebViewController.addBridgeMessageObserver(
                    message: KeeperDappBridge.messageHandlerName,
                    observer: { [weak self] body, senderOrigin in
                        self?.viewModel.didReceiveKeeperBridgeMessage(body: body, senderOrigin: senderOrigin)
                    }
                )
            }
            bridgeWebViewController.didTapCopy = { [weak self] url in
                self?.viewModel.copyDappURL(url: url)
            }

            bridgeWebViewController.didTapShare = { [weak self] url in
                self?.viewModel.shareDappURL(url: url)
            }

            bridgeWebViewController.didTapClose = { [weak self] in
                self?.viewModel.didTapClose()
            }

            bridgeWebViewController.newWindowHandler = { [weak self] url in
                self?.viewModel.didRequestNewWindow(url: url) ?? false
            }

            self.bridgeWebViewController = bridgeWebViewController
        }

        viewModel.currentURLProvider = { [weak self] in
            self?.bridgeWebViewController?.currentURL
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

        viewModel.keeperBridgeInjectHandler = { [weak self] js, containsCredentials in
            await self?.injectKeeperBridgeResponse(js, containsCredentials: containsCredentials)
        }

        viewModel.didChangeCloseButtonVisibility = { [weak self] isVisible in
            self?.bridgeWebViewController?.showsCloseButtonWhenHeaderHidden = isVisible
        }

        viewModel.didUpdateIsLandscapeEnable = { [weak self] in
            if #available(iOS 16.0, *) {
                // Under liquid glass a modal dapp sits in a navigation controller that asks it.
                (self?.navigationController ?? self)?.setNeedsUpdateOfSupportedInterfaceOrientations()
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

        viewModel.didRequestShareText = { [weak self] text in
            guard let self, viewIfLoaded?.window != nil, presentedViewController == nil, !isBeingDismissed,
                  navigationController?.isBeingDismissed != true
            else { return }
            present(
                UIActivityViewController(activityItems: [text], applicationActivities: nil),
                animated: true
            )
        }
    }
}
