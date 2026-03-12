import BigInt
import KeeperCore
import SignRaw
import TKCoordinator
import TKCore
import TonSwift
import UIKit

extension MainCoordinator {
    func openSignRaw(
        wallet: Wallet,
        transferProvider: @escaping () async throws -> Transfer,
        resultHandler: SignRawControllerResultHandler?,
        sendFrom: SendOpen.From,
        appId: String? = nil
    ) {
        guard let windowScene = router.rootViewController.windowScene else { return }

        SignRawPresenter.presentSignRaw(
            windowScene: windowScene,
            windowLevel: .signRaw,
            wallet: wallet,
            transferProvider: transferProvider,
            resultHandler: resultHandler,
            sendFrom: sendFrom,
            appId: appId,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            didRequireSign: { [weak self] transferData, wallet, coordinator, router in
                try await self?.didRequireSign(
                    transferData: transferData,
                    wallet: wallet,
                    coordinator: coordinator,
                    router: router
                )
            },
            didRequestReplanishWallet: { [weak self] wallet, isInternalPurchasing in
                self?.router.dismiss(animated: true) {
                    self?.openBuy(wallet: wallet, isInternalPurchasing: isInternalPurchasing)
                }
            }
        )
    }

    func openTransferSignRaw(
        wallet: Wallet,
        recipient: TonRecipient,
        amount: BigUInt,
        payload: String?,
        stateInit: String?,
        sendFrom: SendOpen.From
    ) {
        let signRaw: () async throws -> SignRawRequest = {
            try await self.createTransferSignRaw(
                wallet: wallet,
                recipient: recipient,
                amount: amount,
                payload: payload,
                stateInit: stateInit
            )
        }

        openSignRaw(wallet: wallet, transferProvider: {
            try .signRaw(
                await signRaw(), forceRelayer: true
            )
        }, resultHandler: nil, sendFrom: sendFrom)
    }

    private func createTransferSignRaw(
        wallet: Wallet,
        recipient: TonRecipient,
        amount: BigUInt,
        payload: String?,
        stateInit: String?
    ) async throws -> SignRawRequest {
        let sendService = keeperCoreMainAssembly.servicesAssembly.sendService()

        let validUntil = await sendService.getTimeoutSafely(wallet: wallet, TTL: DEFAULT_TTL)

        let messages: [SignRawRequestMessage] = [
            SignRawRequestMessage(
                address: .address(recipient.recipientAddress.address),
                amount: UInt64(amount),
                stateInit: stateInit,
                payload: payload
            ),
        ]

        return try SignRawRequest(
            messages: messages,
            validUntil: validUntil,
            from: wallet.address,
            messagesVariants: nil
        )
    }

    @MainActor
    func didRequireSign(
        transferData: TransferData,
        wallet: Wallet,
        coordinator: Coordinator,
        router: ViewControllerRouter
    ) async throws -> SignedTransactions? {
        let coordinator = WalletTransferSignCoordinator(
            router: router,
            wallet: wallet,
            transferData: transferData,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        self.walletTransferSignCoordinator = coordinator

        let result = await coordinator.handleSign(parentCoordinator: coordinator)

        switch result {
        case let .signed(data):
            return data
        case .cancel:
            return nil
        case let .failed(error):
            throw error
        }
    }
}

struct BridgeSignRawResultHandler: SignRawControllerResultHandler {
    var didCancelHandler: (() -> Void)?

    private let app: TonConnectApp
    private let appRequest: TonConnect.SendTransactionRequest
    private let tonConnectService: TonConnectService

    init(
        app: TonConnectApp,
        appRequest: TonConnect.SendTransactionRequest,
        tonConnectService: TonConnectService
    ) {
        self.app = app
        self.appRequest = appRequest
        self.tonConnectService = tonConnectService
    }

    func didConfirm(boc: String) {
        Task {
            try await tonConnectService.confirmRequest(boc: boc, appRequest: appRequest, app: app)
        }
    }

    func didFail(error: any Error) {}

    func didCancel() {
        didCancelHandler?()
        Task {
            try await tonConnectService.cancelRequest(appRequest: appRequest, app: app)
        }
    }
}

struct BridgeSignDataResultHandler: SignDataResultHandler {
    var didCancelHandler: (() -> Void)?

    func didCancel() {
        didCancelHandler?()
        Task {
            try await tonConnectService.cancelSignRequest(appRequest: appRequest, app: app)
        }
    }

    func didSign(signedData: SignedDataResult) {
        Task {
            try await tonConnectService.confirmSignRequest(signed: signedData, appRequest: appRequest, app: app)
        }
    }

    private let app: TonConnectApp
    private let appRequest: TonConnect.SignDataRequest
    private let tonConnectService: TonConnectService

    init(
        app: TonConnectApp,
        appRequest: TonConnect.SignDataRequest,
        tonConnectService: TonConnectService
    ) {
        self.app = app
        self.appRequest = appRequest
        self.tonConnectService = tonConnectService
    }

    func didFail(error: any Error) {}
}
