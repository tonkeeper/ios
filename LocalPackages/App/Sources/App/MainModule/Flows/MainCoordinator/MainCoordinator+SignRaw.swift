import BigInt
import KeeperCore
import SignRaw
import TKCoordinator
import TKCore
import TKLogging
import TonSwift
import UIKit

extension MainCoordinator {
    func openSignRaw(
        wallet: Wallet,
        transferProvider: @escaping () async throws -> Transfer,
        resultHandler: SignRawControllerResultHandler?,
        sendFrom: SendOpen.From,
        appId: String? = nil,
        initiatedBy: InitiatedBy,
        dappUrl: String? = nil,
        utm: UtmParameters = .empty,
        redAnalyticsConfiguration: RedAnalyticsConfiguration? = nil
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
            initiatedBy: initiatedBy,
            dappUrl: dappUrl,
            utm: utm,
            redAnalyticsConfiguration: redAnalyticsConfiguration,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            didRequireSign: { [weak self] transferData, wallet, coordinator, router throws(WalletTransferSignError) in
                guard let self else {
                    throw .cancelled
                }
                return try await didRequireSign(
                    transferData: transferData,
                    wallet: wallet,
                    coordinator: coordinator,
                    router: router
                )
            },
            didRequestReplanishWallet: { [weak self] wallet, isInternalPurchasing in
                guard let self else { return }
                let entrySource = depositAnalyticsSource(for: initiatedBy)
                router.dismiss(animated: true) { [weak self] in
                    self?.openBuy(
                        wallet: wallet,
                        isInternalPurchasing: isInternalPurchasing,
                        entrySource: entrySource
                    )
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
        sendFrom: SendOpen.From,
        initiatedBy: InitiatedBy,
        utm: UtmParameters = .empty
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
        }, resultHandler: nil, sendFrom: sendFrom, initiatedBy: initiatedBy, utm: utm)
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
    ) async throws(WalletTransferSignError) -> SignedTransactions {
        let signCoordinator = WalletTransferSignCoordinator(
            router: router,
            wallet: wallet,
            transferData: transferData,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        self.walletTransferSignCoordinator = signCoordinator

        return try await signCoordinator
            .handleSign(parentCoordinator: coordinator)
            .get()
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
            do {
                try await tonConnectService.confirmRequest(boc: boc, appRequest: appRequest, app: app)
            } catch {
                Log.w("failed to confirm Ton Connect request due to error: \(error)")
            }
        }
    }

    func didFail(error: SomeOf<TransferError, TransactionConfirmationError>) {}

    func didCancel() {
        didCancelHandler?()
        Task {
            do {
                try await tonConnectService.cancelRequest(appRequest: appRequest, app: app)
            } catch {
                Log.w("failed to cancel Ton Connect request due to error: \(error)")
            }
        }
    }
}

struct BridgeSignDataResultHandler: SignDataResultHandler {
    var didCancelHandler: (() -> Void)?

    func didCancel() {
        didCancelHandler?()
        Task {
            do {
                try await tonConnectService.cancelSignRequest(appRequest: appRequest, app: app)
            } catch {
                Log.w("failed to cancel Ton Connect sign request due to error: \(error)")
            }
        }
    }

    func didSign(signedData: SignedDataResult) {
        Task {
            do {
                try await tonConnectService.confirmSignRequest(signed: signedData, appRequest: appRequest, app: app)
            } catch {
                Log.w("failed to confirm Ton Connect sign request due to error: \(error)")
            }
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

    func didFail(error: SignDataRequestFailure) {}
}
