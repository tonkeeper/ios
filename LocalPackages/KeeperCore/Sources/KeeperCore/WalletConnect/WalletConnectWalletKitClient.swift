import Combine
@preconcurrency import Commons
import Foundation
@preconcurrency import ReownWalletKit
import TKLogging

@WalletConnectActor
protocol WalletConnectWalletKitClientProtocol: AnyObject, Sendable {
    func configureIfNeeded() throws(WalletConnectConfigurationError)

    func pair(uriString: String) async throws(WalletConnectPairingError)

    func approveProposal(
        id: String,
        namespaces: [String: SessionNamespace],
        sessionProperties: [String: String]?,
        scopedProperties: [String: String]?
    ) async throws(WalletConnectSessionApprovalError) -> WalletConnectSession

    func rejectProposal(
        id: String,
        reason: RejectionReason
    ) async throws(WalletConnectSessionRejectionError)

    func approveRequest(
        topic: String,
        requestId: RPCID,
        result: WalletConnectResponseValue
    ) async throws(WalletConnectResponseError)

    func rejectRequest(
        topic: String,
        requestId: RPCID,
        error: JSONRPCError
    ) async throws(WalletConnectResponseError)

    func sessionSupports(
        topic: String,
        chain: WalletConnectChain,
        method: WalletConnectMethod,
        event: String
    ) -> Bool

    func walletCapabilitiesScope(topic: String) -> WalletConnectWalletCapabilitiesScope?

    func emitChainChanged(
        topic: String,
        chain: WalletConnectChain
    ) async throws(WalletConnectResponseError)

    func disconnect(topic: String) async throws(WalletConnectResponseError)

    func activeSessions() -> [WalletConnectSession]

    func pendingProposals(topic: String?) -> [WalletConnectProposalContext]

    func pendingRequests(topic: String?) -> [Request]
}

@WalletConnectActor
final class WalletConnectWalletKitClient: WalletConnectWalletKitClientProtocol, Sendable {
    private let configurationProvider: @WalletConnectActor () throws(WalletConnectConfigurationError) -> WalletConnectConfiguration
    private let networkConnectionStatusProvider: WalletConnectNetworkConnectionStatusProvider
    private var configured = false

    init(
        configurationProvider: @escaping @WalletConnectActor () throws(WalletConnectConfigurationError) -> WalletConnectConfiguration,
        networkConnectionStatusProvider: WalletConnectNetworkConnectionStatusProvider
    ) {
        self.configurationProvider = configurationProvider
        self.networkConnectionStatusProvider = networkConnectionStatusProvider
    }

    func configureIfNeeded() throws(WalletConnectConfigurationError) {
        guard !configured else {
            Log.walletConnect.i("configure skipped: already configured")
            return
        }

        Log.walletConnect.i("configure started")
        let configuration: WalletConnectConfiguration
        do {
            configuration = try configurationProvider()
        } catch {
            Log.walletConnect.i("configure failed", error: error)
            throw error
        }

        Networking.configure(
            relayHost: configuration.relayHost,
            groupIdentifier: configuration.groupIdentifier,
            projectId: configuration.projectId,
            socketFactory: WalletConnectDefaultSocketFactory()
        )
        WalletKit.configure(
            metadata: configuration.metadata,
            crypto: WalletConnectCryptoProvider()
        )
        configured = true
        Log.walletConnect.i("configure finished", extraInfo: [
            "relayHost": configuration.relayHost,
            "groupIdentifier": configuration.groupIdentifier,
            "appName": configuration.metadata.name,
            "appURL": configuration.metadata.url,
        ])
    }

    func pair(uriString: String) async throws(WalletConnectPairingError) {
        Log.walletConnect.i("pair requested")

        let uri: WalletConnectURI
        do {
            uri = try WalletConnectURI(uriString: uriString)
        } catch {
            Log.walletConnect.i(
                "pair failed: invalid uri",
                error: error
            )
            throw .invalidURI(uriString)
        }

        do {
            try await WalletKit.instance.pair(uri: uri)
            Log.walletConnect.i("pair submitted")
        } catch {
            Log.walletConnect.i(
                "pair failed",
                error: error
            )
            if case let .network(message) = error as? WalletConnectPairingError {
                throw WalletConnectPairingError.network(message: message)
            }
            if !networkConnectionStatusProvider.isConnected {
                throw WalletConnectPairingError.network(message: walletConnectNetworkDisconnectedMessage)
            }
            throw WalletConnectPairingErrorMapper.map(error)
        }
    }

    func approveProposal(
        id: String,
        namespaces: [String: SessionNamespace],
        sessionProperties: [String: String]?,
        scopedProperties: [String: String]?
    ) async throws(WalletConnectSessionApprovalError) -> WalletConnectSession {
        do {
            let session = try await WalletKit.instance.approve(
                proposalId: id,
                namespaces: namespaces,
                sessionProperties: sessionProperties,
                scopedProperties: scopedProperties
            )
            return WalletConnectSession(
                topic: session.topic,
                dapp: WalletConnectDapp(metadata: session.peer),
                walletId: nil,
                sourceState: .unknown,
                chains: WalletConnectSessionNamespaceBuilder.chains(from: session.namespaces)
            )
        } catch {
            if !networkConnectionStatusProvider.isConnected {
                throw WalletConnectSessionApprovalError.sdk(
                    message: walletConnectNetworkDisconnectedMessage,
                    retryable: true
                )
            }
            throw WalletConnectSessionProposalErrorMapper.mapApproval(
                error,
                proposalId: id
            )
        }
    }

    func rejectProposal(
        id: String,
        reason: RejectionReason
    ) async throws(WalletConnectSessionRejectionError) {
        do {
            try await WalletKit.instance.rejectSession(
                proposalId: id,
                reason: reason
            )
        } catch {
            if !networkConnectionStatusProvider.isConnected {
                throw WalletConnectSessionRejectionError.sdk(
                    message: walletConnectNetworkDisconnectedMessage,
                    retryable: true
                )
            }
            throw WalletConnectSessionProposalErrorMapper.mapRejection(
                error,
                proposalId: id
            )
        }
    }

    func approveRequest(
        topic: String,
        requestId: RPCID,
        result: WalletConnectResponseValue
    ) async throws(WalletConnectResponseError) {
        do {
            try await WalletKit.instance.respond(
                topic: topic,
                requestId: requestId,
                response: .response(anyCodable(from: result))
            )
        } catch {
            if !networkConnectionStatusProvider.isConnected {
                throw WalletConnectResponseError.sdk(
                    message: walletConnectNetworkDisconnectedMessage,
                    retryable: true
                )
            }
            throw WalletConnectResponseErrorMapper.map(
                error,
                requestId: requestId.string,
                topic: topic
            )
        }
    }

    func rejectRequest(
        topic: String,
        requestId: RPCID,
        error: JSONRPCError = .walletConnectUserRejected
    ) async throws(WalletConnectResponseError) {
        do {
            try await WalletKit.instance.respond(
                topic: topic,
                requestId: requestId,
                response: .error(error)
            )
        } catch {
            if !networkConnectionStatusProvider.isConnected {
                throw WalletConnectResponseError.sdk(
                    message: walletConnectNetworkDisconnectedMessage,
                    retryable: true
                )
            }
            throw WalletConnectResponseErrorMapper.map(
                error,
                requestId: requestId.string,
                topic: topic
            )
        }
    }

    func sessionSupports(
        topic: String,
        chain: WalletConnectChain,
        method: WalletConnectMethod,
        event: String
    ) -> Bool {
        guard let blockchain = Blockchain(chain.caip2),
              let session = WalletKit.instance.getSessions().first(where: { $0.topic == topic })
        else {
            return false
        }

        return session.namespaces.values.contains { namespace in
            let hasChain = namespace.chains?.contains(blockchain) == true
                || namespace.accounts.contains { $0.blockchain == blockchain }
            return hasChain
                && namespace.methods.contains(method.rawValue)
                && namespace.events.contains(event)
        }
    }

    func walletCapabilitiesScope(topic: String) -> WalletConnectWalletCapabilitiesScope? {
        guard let session = WalletKit.instance.getSessions().first(where: { $0.topic == topic }) else {
            return nil
        }
        let accounts: [WalletConnectWalletCapabilitiesScope.Account] = session.namespaces.values
            .flatMap(\.accounts)
            .compactMap { account -> WalletConnectWalletCapabilitiesScope.Account? in
                guard let chainId = eip155HexChainId(account.blockchain) else {
                    return nil
                }
                return WalletConnectWalletCapabilitiesScope.Account(
                    address: account.address,
                    chainId: chainId
                )
            }
        return WalletConnectWalletCapabilitiesScope(accounts: accounts)
    }

    func emitChainChanged(
        topic: String,
        chain: WalletConnectChain
    ) async throws(WalletConnectResponseError) {
        guard let blockchain = Blockchain(chain.caip2),
              let chainId = chain.eip155ChainId
        else {
            throw .sdk(message: "Unsupported WalletConnect chain \(chain.caip2)", retryable: false)
        }

        do {
            try await WalletKit.instance.emit(
                topic: topic,
                event: Session.Event(
                    name: "chainChanged",
                    data: Commons.AnyCodable(Int(chainId))
                ),
                chainId: blockchain
            )
        } catch {
            if !networkConnectionStatusProvider.isConnected {
                throw WalletConnectResponseError.sdk(
                    message: walletConnectNetworkDisconnectedMessage,
                    retryable: true
                )
            }
            throw WalletConnectResponseErrorMapper.map(
                error,
                requestId: nil,
                topic: topic
            )
        }
    }

    func disconnect(topic: String) async throws(WalletConnectResponseError) {
        do {
            try await WalletKit.instance.disconnect(topic: topic)
        } catch {
            if !networkConnectionStatusProvider.isConnected {
                throw WalletConnectResponseError.sdk(
                    message: walletConnectNetworkDisconnectedMessage,
                    retryable: true
                )
            }
            throw WalletConnectResponseErrorMapper.map(
                error,
                requestId: nil,
                topic: topic
            )
        }
    }

    func activeSessions() -> [WalletConnectSession] {
        WalletKit.instance.getSessions().map {
            WalletConnectSession(
                topic: $0.topic,
                dapp: WalletConnectDapp(metadata: $0.peer),
                walletId: nil,
                sourceState: .unknown,
                chains: WalletConnectSessionNamespaceBuilder.chains(from: $0.namespaces)
            )
        }
    }

    func pendingProposals(topic: String?) -> [WalletConnectProposalContext] {
        WalletKit.instance.getPendingProposals(topic: topic).map { proposal, context in
            WalletConnectProposalContext(
                proposal: proposal,
                context: context
            )
        }
    }

    func pendingRequests(topic: String?) -> [Request] {
        WalletKit.instance.getPendingRequests(topic: topic).map { $0.request }
    }
}

private func eip155HexChainId(_ blockchain: Blockchain) -> String? {
    let components = blockchain.absoluteString.split(separator: ":")
    guard components.count == 2,
          components[0] == WalletConnectChain.eth.namespace,
          let chainId = Int(components[1])
    else {
        return nil
    }
    return "0x\(String(chainId, radix: 16))"
}

private func anyCodable(from result: WalletConnectResponseValue) -> Commons.AnyCodable {
    switch result {
    case .null:
        return Commons.AnyCodable(nil as String?)
    case let .string(value):
        return Commons.AnyCodable(value)
    case let .object(value):
        return Commons.AnyCodable(any: value)
    case let .json(value):
        return Commons.AnyCodable(any: value.value)
    }
}

private let walletConnectNetworkDisconnectedMessage = "WalletConnect network is not connected"
