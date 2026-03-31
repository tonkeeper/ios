import Foundation
import KeeperCore
import TONWalletKit

class TONConnectWebViewEventsHandler: TONBridgeEventsHandler {
    private let dapp: Dapp
    private let wallet: Wallet?

    var connectionEventHandler: ((Int, TonConnectRequestPayload, TONWalletConnectionRequest) -> Void)?
    var sendTransactionEventHandler: ((Dapp, TonConnect.SendTransactionRequest, @escaping (TonConnectAppsStore.SendResult) -> Void) -> Void)?
    var signDataEventHandler: ((Dapp, TonConnect.SignDataRequest, @escaping (TonConnectAppsStore.SendResult) -> Void) -> Void)?

    init(dapp: Dapp, wallet: Wallet?) {
        self.dapp = dapp
        self.wallet = wallet
    }

    func handle(event: TONWalletKitEvent) throws {
        // For more information about such handling check TONConnectEventsHandler
        guard event.isJsBridge else { return }

        DispatchQueue.main.async { [weak self] in
            self?.handleEvent(event: event)
        }
    }

    func handleEvent(event: TONWalletKitEvent) {
        switch event {
        case let .connectRequest(request):
            guard let manifestUrl = request.event.dAppInfo?.manifestUrl else {
                return
            }

            let payload = TonConnectRequestPayload(
                manifestUrl: manifestUrl,
                items: request.event.requestedItems.map { item -> TonConnectRequestPayload.Item in
                    switch item {
                    case .tonAddr:
                        return .tonAddress
                    case let .tonProof(data):
                        return .tonProof(payload: data.payload)
                    case .unknown:
                        return .unknown
                    }
                }
            )
            connectionEventHandler?(2, payload, request)

        case .disconnect: ()

        case let .transactionRequest(request):
            guard let signRawRequest = SignRawRequest(request: request.event.request) else {
                handle(
                    request: request,
                    result: .error(.badRequest)
                )
                return
            }

            let sendTransactionRequest = TonConnect.SendTransactionRequest(
                params: [signRawRequest],
                id: request.event.id
            )

            sendTransactionEventHandler?(dapp, sendTransactionRequest) { [weak self] in self?.handle(request: request, result: $0) }

        case let .signDataRequest(request):
            let signDataRequest = TonConnect.SignDataRequest(
                params: TonConnectSignDataPayload(data: request.event.payload.data),
                id: request.event.id
            )

            signDataEventHandler?(dapp, signDataRequest) { [weak self] in self?.handle(request: request, result: $0) }
        }
    }

    private func handle(request: TONWalletSignDataRequest, result: TonConnectAppsStore.SendResult) {
        Task {
            switch result {
            case let .error(error):
                try? await request.reject(reason: error.localizedDescription)
            case let .response(data):
                _ = try? await request.approve(rawResponse: data)
            }
        }
    }

    private func handle(request: TONWalletSendTransactionRequest, result: TonConnectAppsStore.SendResult) {
        Task {
            switch result {
            case let .error(error):
                try? await request.reject(reason: error.localizedDescription)
            case let .response(data):
                _ = try? await request.approve(rawResponse: data)
            }
        }
    }
}
