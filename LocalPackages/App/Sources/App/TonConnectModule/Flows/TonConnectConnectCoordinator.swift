import CoreComponents
import KeeperCore
import TKCoordinator
import TKCore
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit
import URKit

enum ConnectError: Error {
    case unknown
    case cancelled
    case noPasscode
}

@MainActor
public protocol TonConnectConnectCoordinatorConnector {
    func connect(
        wallet: Wallet,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply
    ) async throws
}

@MainActor
public struct DefaultTonConnectConnectCoordinatorConnector: TonConnectConnectCoordinatorConnector {
    private let tonConnectAppsStore: TonConnectAppsStore

    public func connect(
        wallet: Wallet,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply
    ) async throws {
        try await tonConnectAppsStore.connect(
            wallet: wallet,
            parameters: parameters,
            manifest: manifest,
            signTonProofHandler: signTonProofHandler,
            keeperVersion: InfoProvider.appVersion()
        )
    }

    public init(tonConnectAppsStore: TonConnectAppsStore) {
        self.tonConnectAppsStore = tonConnectAppsStore
    }
}

@MainActor
public struct BridgeTonConnectConnectCoordinatorConnector: TonConnectConnectCoordinatorConnector {
    private let tonConnectAppsStore: TonConnectAppsStore
    private let connectionResponseHandler: (TonConnectAppsStore.ConnectResult) -> Void

    public init(tonConnectAppsStore: TonConnectAppsStore, connectionResponseHandler: @escaping (TonConnectAppsStore.ConnectResult) -> Void) {
        self.tonConnectAppsStore = tonConnectAppsStore
        self.connectionResponseHandler = connectionResponseHandler
    }

    public func connect(
        wallet: Wallet,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply
    ) async throws {
        let response = await tonConnectAppsStore.connectBridgeDapp(
            wallet: wallet,
            parameters: parameters,
            manifest: manifest,
            signTonProofHandler: signTonProofHandler,
            keeperVersion: InfoProvider.appVersion()
        )
        connectionResponseHandler(response)
        guard case let .error(error) = response else {
            return
        }
        throw error
    }
}

@MainActor
public final class TonConnectConnectCoordinator: RouterCoordinator<WindowRouter> {
    public enum Flow {
        case common
        case deeplink
    }

    public var didConnect: (() -> Void)?
    public var didCancel: (() -> Void)?
    public var didFail: (() -> Void)?
    public var didRequestOpeningBrowser: ((_ manifest: TonConnectManifest) -> Void)?

    private let connector: TonConnectConnectCoordinatorConnector
    private let parameters: TonConnectParameters
    private let manifest: TonConnectManifest
    private let showWalletPicker: Bool
    private let isSilentConnect: Bool
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly

    private let flow: Flow

    public init(
        router: WindowRouter,
        flow: Flow,
        connector: TonConnectConnectCoordinatorConnector,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        showWalletPicker: Bool,
        isSilentConnect: Bool,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.connector = connector
        self.parameters = parameters
        self.manifest = manifest
        self.showWalletPicker = showWalletPicker
        self.isSilentConnect = isSilentConnect
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.flow = flow
        super.init(router: router)
    }

    override public func start() {
        openTonConnectConnect()
    }
}

private extension TonConnectConnectCoordinator {
    func openTonConnectConnect() {
        if isSilentConnect {
            let rootViewController = UIViewController()
            router.window.rootViewController = rootViewController
            router.window.makeKeyAndVisible()
            guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
                  let viewController = router.window.rootViewController?.topPresentedViewController()
            else {
                didFail?()
                return
            }
            let attemptTracker = makeConnectAttemptTracker()
            Task {
                let isSuccess = await connect(
                    parameters: TonConnectConnectParameters(
                        parameters: parameters,
                        manifest: manifest,
                        wallet: wallet
                    ),
                    attemptTracker: attemptTracker,
                    fromViewController: viewController
                )
                if isSuccess {
                    didConnect?()
                } else {
                    didCancel?()
                }
            }
        } else {
            openTonConnectConnectScreen()
        }
    }

    func openTonConnectConnectScreen() {
        let rootViewController = UIViewController()
        router.window.rootViewController = rootViewController
        router.window.makeKeyAndVisible()

        let module = TonConnectConnectAssembly.module(
            parameters: parameters,
            manifest: manifest,
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            walletNotificationStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
            notificationsService: keeperCoreMainAssembly.servicesAssembly.notificationsService(
                walletNotificationsStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
                tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
            ),
            pushTokenProvider: PushNotificationTokenProvider(),
            showWalletPicker: showWalletPicker,
            isSafeMode: {
                switch flow {
                case .common:
                    return false
                case .deeplink:
                    return true
                }
            }()
        )

        let attemptTracker = makeConnectAttemptTracker()

        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: module.view
        )

        module.output.didTapWalletPicker = { [weak self, weak bottomSheetViewController, weak input = module.input] wallet in
            guard let bottomSheetViewController else {
                self?.didFail?()
                return
            }
            self?.openWalletPicker(
                wallet: wallet,
                fromViewController: bottomSheetViewController,
                didSelectWallet: { wallet in
                    input?.setWallet(wallet)
                }
            )
        }

        module.output.didTapOpenBrowserAndConnect = { [weak bottomSheetViewController] manifest in
            bottomSheetViewController?.dismiss { [weak self] in
                self?.didRequestOpeningBrowser?(manifest)
                self?.didCancel?()
            }
        }

        module.output.connect = { [weak self, weak bottomSheetViewController] connectParameters in
            guard let self, let bottomSheetViewController else { return false }
            return await self.connect(
                parameters: connectParameters,
                attemptTracker: attemptTracker,
                fromViewController: bottomSheetViewController
            )
        }

        module.output.didConnect = { [weak self, weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss {
                self?.didConnect?()
            }
            if let returnStrategy = self?.parameters.returnStrategy {
                guard let url = URL(string: returnStrategy) else {
                    return
                }
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        }

        bottomSheetViewController.didClose = { [weak self] _ in
            self?.cancelConnectWalletSession(
                attemptTracker: attemptTracker
            )
            self?.didCancel?()
        }

        bottomSheetViewController.present(fromViewController: rootViewController)
    }

    func connect(
        parameters: TonConnectConnectParameters,
        attemptTracker: TonConnectConnectAttemptTracker,
        fromViewController: UIViewController
    ) async -> Bool {
        attemptTracker.start(
            manifestHost: parameters.manifest.host,
            returnStrategy: parameters.parameters.returnStrategy
        )
        let signTonProofHandler: (String) async throws -> TonConnect.ConnectItemReply = { [weak self, unowned fromViewController] payload in
            guard let self = self else { throw ConnectError.unknown }

            let wallet = parameters.wallet
            let address = try wallet.address
            let timestamp = UInt64(Date().timeIntervalSince1970)

            let signatureData: TonConnect.SignatureData = .init(address: address, domain: .init(domain: parameters.manifest.host), timestamp: timestamp, payload: payload)

            switch wallet.identity.kind {
            case let .Ledger(_, _, ledgerDevice):
                let signature = try await self.handleLedgerProof(
                    fromViewController: fromViewController,
                    signatureData: signatureData,
                    wallet: wallet,
                    ledgerDevice: ledgerDevice
                )
                return .tonProofSigned(
                    TonConnect.TonProofItemReplySigned.success(
                        TonConnect.TonProofItemReplySignedSuccess(
                            data: signatureData,
                            signature: signature
                        )
                    )
                )
            case let .Keystone(publicKey, xfp, path, walletContractVersion):
                return try await .tonProofSigned(
                    .success(.init(
                        data: signatureData,
                        signature: self.handleKeystoneSign(
                            fromViewController: fromViewController,
                            signatureData: signatureData,
                            wallet: wallet,
                            publicKey: publicKey,
                            path: path,
                            xfp: xfp,
                            revision: walletContractVersion,
                            network: wallet.identity.network
                        )
                    ))
                )
            default:
                return try await .tonProofSigned(
                    .success(
                        .init(
                            data: signatureData,
                            signature: self.handleCommonProof(
                                signatureData: signatureData,
                                fromViewController: fromViewController,
                                wallet: wallet
                            )
                        )
                    )
                )
            }
        }

        do {
            try await connector.connect(
                wallet: parameters.wallet,
                parameters: parameters.parameters,
                manifest: parameters.manifest,
                signTonProofHandler: signTonProofHandler
            )
            attemptTracker.finishSuccess()
            return true
        } catch {
            let outcome = connectOutcome(for: error)
            switch outcome {
            case .success:
                attemptTracker.finishSuccess()
            case .cancel:
                attemptTracker.finishCancel()
            case .fail:
                attemptTracker.finishFailure(error)
            }
            return false
        }
    }

    func cancelConnectWalletSession(attemptTracker: TonConnectConnectAttemptTracker) {
        attemptTracker.finishCancel()
    }

    var redAttemptSource: RedAnalyticsAttemptSource {
        switch connector {
        case _ as TONWalletKitCoordinatorConnector:
            .tonconnectRemote
        default:
            .tonconnectLocal
        }
    }

    func connectOutcome(for error: Error) -> OpTerminal.Outcome {
        if let connectError = error as? ConnectError {
            switch connectError {
            case .cancelled, .noPasscode:
                return .cancel
            case .unknown:
                break
            }
        }
        return .fail
    }

    func makeConnectAttemptTracker() -> TonConnectConnectAttemptTracker {
        TonConnectConnectAttemptTracker(
            makeSession: { [coreAssembly, keeperCoreMainAssembly] in
                RedAnalyticsSessionHolder(
                    analytics: coreAssembly.analyticsProvider,
                    configurationAssembly: keeperCoreMainAssembly.configurationAssembly
                )
            },
            attemptSource: redAttemptSource,
            isSafeMode: flow == .deeplink
        )
    }

    func handleKeystoneSign(
        fromViewController: UIViewController,
        signatureData: TonConnect.SignatureData,
        wallet: Wallet,
        publicKey: TonSwift.PublicKey,
        path: String?,
        xfp: String?,
        revision: WalletContractVersion,
        network: Network
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                do {
                    var cryptoKeypath: CryptoKeyPath? = nil
                    if let xfp = xfp {
                        if let path = path {
                            cryptoKeypath = try CryptoKeyPath(components: CryptoPath(string: path), sourceFingerprint: UInt64(xfp), depth: nil)
                        }
                    }

                    let tonSignRequest = try TonSignRequest(requestId: nil, signData: signatureData.data(), dataType: 2, cryptoKeypath: cryptoKeypath, address: wallet.address.toFriendly(bounceable: false).toString(), origin: "Tonkeeper")

                    let ur = try UR(type: "ton-sign-request", cbor: tonSignRequest.toCBOR())

                    let module = KeystoneSignAssembly.module(
                        transaction: ur,
                        wallet: wallet,
                        assembly: self.keeperCoreMainAssembly,
                        coreAssembly: self.coreAssembly
                    )
                    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)

                    bottomSheetViewController.didClose = { [weak bottomSheetViewController] isInteractivly in
                        guard isInteractivly else { return }
                        bottomSheetViewController?.dismiss(completion: {
                            continuation.resume(throwing: ConnectError.cancelled)
                        })
                    }

                    module.output.didScanSignedTransaction = { [weak bottomSheetViewController] ur in
                        bottomSheetViewController?.dismiss {
                            guard let signature = try? TonSignature(cbor: ur.cbor).signature else {
                                continuation.resume(throwing: ConnectError.unknown)
                                return
                            }
                            continuation.resume(returning: signature)
                        }
                    }

                    bottomSheetViewController.present(fromViewController: fromViewController)
                } catch {
                    continuation.resume(throwing: ConnectError.unknown)
                }
            }
        }
    }

    func handleLedgerProof(fromViewController: UIViewController, signatureData: TonConnect.SignatureData, wallet: Wallet, ledgerDevice: Wallet.LedgerDevice) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let module = LedgerConfirmAssembly.module(
                    confirmItem: .signatureData(signatureData),
                    wallet: wallet,
                    ledgerDevice: ledgerDevice,
                    coreAssembly: self.coreAssembly
                )

                let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)

                bottomSheetViewController.didClose = { _ in
                    continuation.resume(throwing: ConnectError.cancelled)
                }

                module.output.didCancel = { [weak bottomSheetViewController] in
                    bottomSheetViewController?.dismiss(completion: {
                        continuation.resume(throwing: ConnectError.cancelled)
                    })
                }

                module.output.didSign = { [weak bottomSheetViewController] signature in
                    bottomSheetViewController?.dismiss(completion: {
                        switch signature {
                        case let .proof(data):
                            continuation.resume(returning: data)
                        default:
                            continuation.resume(throwing: ConnectError.unknown)
                        }
                    })
                }

                module.output.didError = { [weak bottomSheetViewController] _ in
                    bottomSheetViewController?.dismiss(completion: {
                        continuation.resume(throwing: ConnectError.unknown)
                    })
                }

                bottomSheetViewController.present(fromViewController: fromViewController)
            }
        }
    }

    func handleCommonProof(
        signatureData: TonConnect.SignatureData,
        fromViewController: UIViewController,
        wallet: Wallet
    ) async throws -> Data {
        guard let passcode = await PasscodeInputCoordinator.getPasscode(
            parentCoordinator: self,
            parentRouter: ViewControllerRouter(rootViewController: fromViewController),
            mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
        ) else { throw ConnectError.noPasscode }

        let mnemonic = try await keeperCoreMainAssembly.secureAssembly.mnemonicsRepository().getMnemonic(wallet: wallet, password: passcode)
        let keyPair = try MnemonicLegacy.anyMnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
        let privateKey = keyPair.privateKey

        let signature: TonConnect.Signature = .init(signatureData: signatureData, privateKey: privateKey)
        return try signature.signature()
    }

    func openWalletPicker(wallet: Wallet, fromViewController: UIViewController, didSelectWallet: @escaping (Wallet) -> Void) {
        let model = TonConnectWalletsPickerListModel(
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            selectedWallet: wallet
        )
        model.didSelectWallet = { wallet in
            didSelectWallet(wallet)
        }

        let module = WalletsListAssembly.module(
            model: model,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            totalBalancesStore: keeperCoreMainAssembly.storesAssembly.totalBalanceStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)

        module.output.addButtonEvent = { [weak self, unowned bottomSheetViewController] in
            self?.openAddWallet(router: ViewControllerRouter(rootViewController: bottomSheetViewController)) {}
        }

        module.output.didSelectWallet = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        bottomSheetViewController.present(fromViewController: fromViewController)
    }

    func openAddWallet(router: ViewControllerRouter, onAddWallets: @escaping () -> Void) {
        let module = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
            )
        )

        let coordinator = module.createAddWalletCoordinator(
            options: [.createRegular, .importRegular, .importWatchOnly, .importTestnet, .importTetra, .signer],
            router: router
        )
        coordinator.didAddWallets = {
            onAddWallets()
        }

        addChild(coordinator)
        coordinator.start()
    }
}
