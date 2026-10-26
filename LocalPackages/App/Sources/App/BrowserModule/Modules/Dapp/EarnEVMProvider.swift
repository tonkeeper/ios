import Foundation
import KeeperCore
import TKLogging

@MainActor
final class EarnEVMProvider {
    typealias Signer = (Wallet, WalletConnectSessionRequest) async throws(WalletConnectSigningError) -> WalletConnectResponseValue

    var onEvent: ((EVMProviderEvent) -> Void)?
    var onSigning: ((EarnSigningEvent) -> Void)?
    var onTransactionSent: ((Wallet, WalletConnectChain, WalletConnectEVMTransaction) -> Void)?

    private var chain: WalletConnectChain = .eth
    private var reportedAccounts: [String]?
    private let dapp: WalletConnectDapp
    private let walletsStore: WalletsStore
    private let sign: Signer

    init(dapp: WalletConnectDapp, walletsStore: WalletsStore, sign: @escaping Signer) {
        self.dapp = dapp
        self.walletsStore = walletsStore
        self.sign = sign
        walletsStore.addObserver(self) { observer, event in
            switch event {
            case .didChangeActiveWallet, .didUpdateWalletMultichain:
                Task { @MainActor in
                    observer.reportAccountsIfChanged()
                }
            default:
                break
            }
        }
    }

    func handle(
        _ request: EVMProviderRequest,
        pageURL: URL?,
        completion: @escaping (DappMessageHandlerResult) -> Void
    ) {
        let signing = SigningRequest(request, chain: chain, pageURL: pageURL)
        signing.map { report($0, .requested) }

        guard let wallet = activeWallet, let address = wallet.walletConnectAddress(for: chain) else {
            if request == .accounts {
                reportedAccounts = []
            }
            signing.map { report($0, .failed(.noAccount)) }
            completion(rejection(.unauthorized, EVMProviderBridge.ErrorMessage.noAccount))
            return
        }

        switch request {
        case .accounts:
            reportedAccounts = [address]
            completion(response([address]))
        case .chainId:
            completion(response(chainIdHex))
        case .netVersion:
            completion(response(String(chainId)))
        case let .switchChain(chainId):
            completion(switchChain(to: chainId, wallet: wallet))
        case .sendTransaction, .personalSign, .signTypedDataV4:
            signing.map { sign($0, wallet: wallet, completion: completion) }
        case .unsupported:
            completion(rejection(.unsupportedMethod, EVMProviderBridge.ErrorMessage.unsupportedMethod))
        }
    }
}

private extension EarnEVMProvider {
    struct SigningRequest {
        let method: WalletConnectMethod
        let chain: WalletConnectChain
        let pageURL: URL?
        let payload: WalletConnectRequestPayload

        init?(_ request: EVMProviderRequest, chain: WalletConnectChain, pageURL: URL?) {
            self.chain = chain
            self.pageURL = pageURL
            switch request {
            case let .sendTransaction(transaction):
                method = .ethSendTransaction
                payload = .evmTransaction(transaction, send: true)
            case let .personalSign(message, address):
                method = .personalSign
                payload = .signMessage(WalletConnectSignMessage(address: address, message: message, kind: .personal))
            case let .signTypedDataV4(address, typedData):
                method = .ethSignTypedDataV4
                payload = .signMessage(WalletConnectSignMessage(address: address, message: typedData, kind: .typedDataV4))
            case .accounts, .chainId, .netVersion, .switchChain, .unsupported:
                return nil
            }
        }
    }

    var activeWallet: Wallet? {
        do {
            return try walletsStore.activeWallet
        } catch {
            Log.w("earn evm request without an active wallet", extraInfo: ["error": "\(error)"])
            return nil
        }
    }

    var accounts: [String] {
        activeWallet.flatMap { $0.walletConnectAddress(for: chain) }.map { [$0] } ?? []
    }

    var chainId: Int {
        chain.eip155ChainId.map(Int.init) ?? 1
    }

    var chainIdHex: String {
        EVMProviderBridge.chainIdHex(chainId)
    }

    func switchChain(to requestedChainId: String, wallet: Wallet) -> DappMessageHandlerResult {
        let normalized = requestedChainId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.hasPrefix("0x"),
              let decimalChainId = Int(normalized.dropFirst(2), radix: 16),
              let target = WalletConnectChain(caip2: "eip155:\(decimalChainId)"),
              wallet.walletConnectAddress(for: target) != nil
        else {
            return rejection(.unrecognizedChain, EVMProviderBridge.ErrorMessage.unrecognizedChain)
        }

        if target != chain {
            chain = target
            onEvent?(.chainChanged(chainIdHex: chainIdHex))
        }
        return response(EVMProviderBridge.Null())
    }

    func sign(
        _ signing: SigningRequest,
        wallet: Wallet,
        completion: @escaping (DappMessageHandlerResult) -> Void
    ) {
        let request: WalletConnectSessionRequest
        do throws(WalletConnectRequestParsingError) {
            request = try WalletConnectRequestFactory.makeRequest(
                id: UUID().uuidString,
                topic: dapp.url,
                method: signing.method,
                chain: signing.chain,
                payload: signing.payload,
                dapp: dapp,
                source: nil,
                walletId: wallet.id
            )
        } catch {
            Log.w("earn evm request rejected", extraInfo: ["method": signing.method.rawValue, "error": "\(error)"])
            report(signing, .failed(.invalidRequest(error)))
            completion(rejection(.internalError, EVMProviderBridge.ErrorMessage.malformedRequest))
            return
        }

        Task { [sign] in
            let value: WalletConnectResponseValue
            do throws(WalletConnectSigningError) {
                value = try await sign(wallet, request)
            } catch .canceled {
                report(signing, .rejected)
                completion(rejection(.userRejected, EVMProviderBridge.ErrorMessage.userRejected))
                return
            } catch {
                Log.w("earn evm signing failed", extraInfo: ["method": signing.method.rawValue, "error": "\(error)"])
                report(signing, .failed(.signer(error)))
                completion(rejection(.internalError, EVMProviderBridge.ErrorMessage.signingFailed))
                return
            }

            let result = result(for: value)
            guard case .success = result else {
                report(signing, .failed(.unexpectedResponse))
                completion(result)
                return
            }
            report(signing, .signed)
            if case let .evmTransaction(transaction, _) = signing.payload {
                onTransactionSent?(wallet, signing.chain, transaction)
            }
            completion(result)
        }
    }

    func reportAccountsIfChanged() {
        let accounts = accounts
        guard accounts != reportedAccounts else { return }
        reportedAccounts = accounts
        onEvent?(.accountsChanged(accounts))
    }

    func report(_ signing: SigningRequest, _ stage: EarnSigningEvent.Stage) {
        onSigning?(EarnSigningEvent(method: signing.method, chain: signing.chain, pageURL: signing.pageURL, stage: stage))
    }

    func result(for value: WalletConnectResponseValue) -> DappMessageHandlerResult {
        switch value {
        case let .string(string):
            response(string)
        case .null:
            response(EVMProviderBridge.Null())
        case .object, .json:
            rejection(.internalError, EVMProviderBridge.ErrorMessage.signingFailed)
        }
    }

    func response(_ value: some Encodable) -> DappMessageHandlerResult {
        guard let json = EVMProviderBridge.responseJson(value) else {
            return rejection(.internalError, EVMProviderBridge.ErrorMessage.malformedRequest)
        }
        return .success(Data(json.utf8))
    }

    func rejection(_ code: EVMProviderBridge.ErrorCode, _ message: String) -> DappMessageHandlerResult {
        .rejected(code: code.rawValue, message: message)
    }
}
