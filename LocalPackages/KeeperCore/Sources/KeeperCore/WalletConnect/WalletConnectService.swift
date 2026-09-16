import Foundation
@preconcurrency import ReownWalletKit
import TKLogging

public enum WalletConnectServiceEvent: Sendable, Equatable {
    case pairingStarted(pairingTopic: String, source: DappConnectionSource)
    case pairingExpired(pairingTopic: String, source: DappConnectionSource)

    case sessionProposal(WalletConnectSessionProposal)
    case sessionProposalExpired(WalletConnectSessionProposal)

    case sessionRequest(WalletConnectSessionRequest)
    case sessionRequestExpired(topic: String, requestId: String)

    case sessionSettled(WalletConnectSession)
    case sessionDeleted(topic: String)

    case error(WalletConnectErrorEvent)
}

@WalletConnectActor
public protocol WalletConnectService: Sendable {
    func events() async -> AsyncStream<WalletConnectServiceEvent>

    func startedEvents() async -> AsyncStream<WalletConnectServiceEvent>

    func pair(
        uri: String,
        source: DappConnectionSource
    ) async throws(WalletConnectPairingError)

    func approveProposal(
        id: String,
        wallet: Wallet
    ) async throws(WalletConnectSessionApprovalError)

    func rejectProposal(
        id: String
    ) async throws(WalletConnectSessionRejectionError)

    func approveRequest(
        id: String,
        topic: String,
        result: WalletConnectResponseValue
    ) async throws(WalletConnectResponseError)

    func rejectRequest(
        id: String,
        topic: String
    ) async throws(WalletConnectResponseError)

    func rejectRequest(
        id: String,
        topic: String,
        reason: WalletConnectRequestRejectionReason
    ) async throws(WalletConnectResponseError)

    func disconnect(
        topic: String
    ) async throws(WalletConnectResponseError)

    func removeLocalSession(
        topic: String
    ) async throws(WalletConnectResponseError)

    func activeSessions() async -> [WalletConnectSession]
}

@WalletConnectActor
public final class WalletConnectServiceImplementation: WalletConnectService, Sendable {
    private nonisolated let eventsMulticast: MulticastAsyncStream<WalletConnectServiceEvent>
    private let eventStream: WalletConnectEventStream
    private let network: WalletConnectWalletKitClientProtocol
    private let sessionRepository: WalletConnectSessionRepository
    private let sessionReconciler: WalletConnectSessionReconciler
    private let autoRejectService: WalletConnectAutoRejectService
    private let startupCoordinator: WalletConnectStartupCoordinator
    private let pairingCoordinator: WalletConnectPairingCoordinator
    private let proposalCoordinator: WalletConnectSessionProposalCoordinator
    private let requestCoordinator: WalletConnectSessionRequestCoordinator

    private var eventsTask: Task<Void, Never>?
    private var settlingSessionTopics = Set<String>()

    init(
        eventStream: WalletConnectEventStream,
        network: WalletConnectWalletKitClientProtocol,
        sessionRepository: WalletConnectSessionRepository,
        pairingSourceStore: WalletConnectPairingSourceStore,
        parser: WalletConnectMethodParser = WalletConnectMethodParser(),
        accountResolver: WalletConnectAccountResolver = WalletConnectAccountResolver(),
        namespaceBuilder: WalletConnectSessionNamespaceBuilder = WalletConnectSessionNamespaceBuilder(),
        autoRejectService: WalletConnectAutoRejectService,
        pairingProposalTimeoutNanoseconds: UInt64 = WalletConnectPairingTimeouts.defaultProposalNanoseconds
    ) {
        let eventsMulticast = MulticastAsyncStream<WalletConnectServiceEvent>()
        self.eventsMulticast = eventsMulticast
        self.eventStream = eventStream
        self.network = network
        self.sessionRepository = sessionRepository
        self.sessionReconciler = WalletConnectSessionReconciler(repository: sessionRepository)
        self.autoRejectService = autoRejectService
        self.startupCoordinator = WalletConnectStartupCoordinator(
            eventStream: eventStream,
            network: network
        )
        self.pairingCoordinator = WalletConnectPairingCoordinator(
            eventSink: eventsMulticast,
            sourceStore: pairingSourceStore,
            pairingProposalTimeoutNanoseconds: pairingProposalTimeoutNanoseconds
        )
        self.proposalCoordinator = WalletConnectSessionProposalCoordinator(
            network: network,
            accountResolver: accountResolver,
            namespaceBuilder: namespaceBuilder
        )
        self.requestCoordinator = WalletConnectSessionRequestCoordinator(
            network: network,
            parser: parser
        )
    }

    deinit {
        eventsTask?.cancel()
    }

    public func events() async -> AsyncStream<WalletConnectServiceEvent> {
        await eventsMulticast.unicast()
    }

    public func startedEvents() async -> AsyncStream<WalletConnectServiceEvent> {
        let stream = await events()
        await start()
        return stream
    }

    public func start() async {
        do {
            try await ensureStarted()
        } catch {
            emit(.error(WalletConnectErrorEvent(topic: nil, message: "\(error)")))
            logWalletConnectConfigurationFailure(error)
        }
    }

    public func pair(
        uri: String,
        source: DappConnectionSource
    ) async throws(WalletConnectPairingError) {
        do {
            try await ensureStarted()
        } catch {
            throw pairingError(error)
        }

        let preparedPairing: WalletConnectPreparedPairing
        do {
            preparedPairing = try pairingCoordinator.preparePairing(
                uri: uri,
                source: source
            )
        } catch {
            Log.walletConnect.w(
                "pairing preparation failed",
                error: error,
                extraInfo: ["source": "\(source)"]
            )
            throw error
        }
        let pairingTopic = preparedPairing.pairingTopic
        guard !preparedPairing.isDuplicate else {
            logDuplicatePairingIgnored(pairingTopic: pairingTopic, source: preparedPairing.source)
            return
        }

        pairingCoordinator.startPairing(pairingTopic: pairingTopic)

        do {
            try await network.pair(uriString: WalletConnectURIParser.normalized(uri))
        } catch {
            pairingCoordinator.cancelPairing(
                pairingTopic: pairingTopic,
                removeSource: true
            )
            throw error
        }
    }

    public func approveProposal(
        id: String,
        wallet: Wallet
    ) async throws(WalletConnectSessionApprovalError) {
        let approvedProposal = try await proposalCoordinator.approve(
            id: id,
            wallet: wallet
        )
        try await finishApprovedProposal(approvedProposal)
    }

    public func rejectProposal(
        id: String
    ) async throws(WalletConnectSessionRejectionError) {
        try await proposalCoordinator.reject(id: id)
    }

    public func approveRequest(
        id: String,
        topic: String,
        result: WalletConnectResponseValue
    ) async throws(WalletConnectResponseError) {
        try await requestCoordinator.approve(
            id: id,
            topic: topic,
            result: result
        )
    }

    public func rejectRequest(
        id: String,
        topic: String
    ) async throws(WalletConnectResponseError) {
        try await rejectRequest(
            id: id,
            topic: topic,
            reason: .userRejected
        )
    }

    public func rejectRequest(
        id: String,
        topic: String,
        reason: WalletConnectRequestRejectionReason
    ) async throws(WalletConnectResponseError) {
        try await requestCoordinator.reject(
            id: id,
            topic: topic,
            reason: reason
        )
    }

    public func disconnect(
        topic: String
    ) async throws(WalletConnectResponseError) {
        do {
            try await network.disconnect(topic: topic)
        } catch {
            guard shouldTreatDisconnectFailureAsMissingSession(error, topic: topic) else {
                throw error
            }
            Log.walletConnect.i(
                "SDK session is already missing, removing stale local mapping",
                error: error
            )
        }

        clearDisconnectedSessionRuntimeState(topic: topic, context: "disconnect")
        do {
            try sessionRepository.removeSession(
                topic: topic,
                context: "session disconnected"
            )
        } catch {
            throw .storage(message: error.logDescription)
        }
    }

    public func removeLocalSession(
        topic: String
    ) async throws(WalletConnectResponseError) {
        clearDisconnectedSessionRuntimeState(topic: topic, context: "local session cleanup")
        try removeStoredSession(topic: topic, context: "local session cleanup")
        emit(.sessionDeleted(topic: topic))
        logSessionDeleted(topic: topic)
    }

    public func activeSessions() async -> [WalletConnectSession] {
        do {
            try await ensureStarted()
        } catch {
            emit(.error(WalletConnectErrorEvent(topic: nil, message: "\(error)")))
            logWalletConnectConfigurationFailure(error)
            return []
        }

        let sdkSessions = network.activeSessions()
        let reconciliation = sessionReconciler.reconcile(sdkSessions: sdkSessions)
        if let error = reconciliation.storageError {
            emit(.error(WalletConnectErrorEvent(topic: nil, message: "\(error)")))
        }
        let orphanTopics = reconciliation.orphanTopics
            .filter { !settlingSessionTopics.contains($0) }
        let unresolvedOrphanTopics = await disconnectOrphanSessions(
            topics: orphanTopics,
            context: "active sessions reconciliation"
        )
        guard !unresolvedOrphanTopics.isEmpty else {
            return reconciliation.sessions.filter { $0.walletId != nil }
        }
        return reconciliation.sessions.filter { session in
            session.walletId != nil || unresolvedOrphanTopics.contains(session.topic)
        }
    }
}

private extension WalletConnectServiceImplementation {
    func ensureStarted() async throws(WalletConnectConfigurationError) {
        startEventsTaskIfNeeded()
        let shouldHydratePendingState = try await startupCoordinator.start()
        if shouldHydratePendingState {
            await hydratePendingState()
        }
    }

    func startEventsTaskIfNeeded() {
        if eventsTask == nil {
            eventsTask = Task { [weak self, eventStream] in
                for await event in eventStream.stream {
                    guard let self else {
                        return
                    }
                    await self.handle(rawEvent: event)
                }
            }
        }
    }

    func hydratePendingState() async {
        for proposal in network.pendingProposals(topic: nil) {
            handleProposalReceived(proposal)
        }
        for request in network.pendingRequests(topic: nil) {
            await handleRequestReceived(request)
        }
    }

    func handle(rawEvent event: WalletConnectRawEvent) async {
        switch event {
        case let .proposalReceived(proposal):
            handleProposalReceived(proposal)
        case let .proposalExpired(proposal):
            handleProposalExpired(proposal)
        case let .requestReceived(request, _):
            await handleRequestReceived(request)
        case let .requestExpired(requestId):
            handleRequestExpired(requestId: requestId.string)
        case let .sessionSettled(session):
            handleSessionSettled(session)
        case let .sessionDeleted(topic, _):
            handleSessionDeleted(topic: topic)
        }
    }

    func handleProposalReceived(
        _ proposalContext: WalletConnectProposalContext
    ) {
        let source = pairingCoordinator.source(
            pairingTopic: proposalContext.pairingTopic,
            fallback: .deeplink
        )
        pairingCoordinator.markPairingActive(pairingTopic: proposalContext.pairingTopic)
        pairingCoordinator.completePendingPairing(pairingTopic: proposalContext.pairingTopic)
        guard let proposal = proposalCoordinator.receive(
            proposalContext,
            source: source
        ) else { return }
        emit(.sessionProposal(proposal))
        logSessionProposalReceived(proposal)
    }

    func handleProposalExpired(_ rawProposal: Session.Proposal) {
        guard let proposal = proposalCoordinator.expire(rawProposal) else {
            return
        }
        emit(.sessionProposalExpired(proposal))
        logSessionProposalExpired(proposal)
    }

    func handleRequestReceived(_ request: Request) async {
        let result = requestCoordinator.receive(
            request,
            sessionContext: sessionContext(topic: request.topic)
        )
        switch result {
        case let .sessionRequest(sessionRequest):
            if case let .walletCapabilities(capabilities) = sessionRequest.payload {
                await handleWalletGetCapabilitiesRequest(
                    sessionRequest,
                    capabilities: capabilities
                )
            } else if case let .switchEthereumChain(targetChain) = sessionRequest.payload {
                await handleSwitchEthereumChainRequest(
                    sessionRequest,
                    targetChain: targetChain
                )
            } else {
                emit(.sessionRequest(sessionRequest))
            }
        case let .missingDapp(action),
             let .requestError(action):
            autoReject(action)
            emit(.error(action.errorEvent))
        case let .missingWalletMapping(action):
            _ = await disconnectOrphanSession(
                topic: action.topic,
                context: "request missing wallet mapping"
            )
            autoReject(action)
            emit(.error(action.errorEvent))
        case .duplicate:
            break
        }
    }

    func handleWalletGetCapabilitiesRequest(
        _ request: WalletConnectSessionRequest,
        capabilities: WalletConnectWalletCapabilitiesRequest
    ) async {
        guard let scope = network.walletCapabilitiesScope(topic: request.topic) else {
            await rejectWalletGetCapabilitiesRequest(request, error: .walletConnectUnauthorized)
            return
        }

        switch scope.unsupportedAtomicResponse(for: capabilities) {
        case let .response(response):
            do {
                try await requestCoordinator.approve(
                    id: request.id,
                    topic: request.topic,
                    result: response
                )
            } catch {
                emit(.error(WalletConnectErrorEvent(topic: request.topic, message: "\(error)")))
            }
        case .unauthorized:
            await rejectWalletGetCapabilitiesRequest(request, error: .walletConnectUnauthorized)
        }
    }

    func rejectWalletGetCapabilitiesRequest(
        _ request: WalletConnectSessionRequest,
        error: JSONRPCError
    ) async {
        do {
            try await requestCoordinator.reject(
                id: request.id,
                topic: request.topic,
                error: error
            )
        } catch {
            emit(.error(WalletConnectErrorEvent(topic: request.topic, message: "\(error)")))
        }
    }

    func handleRequestExpired(requestId: String) {
        autoRejectService.cancelRequests(
            requestId: requestId,
            context: "request expired"
        )
        let expiredRequests = requestCoordinator.expire(requestId: requestId)
        for request in expiredRequests {
            autoRejectService.cancelRequest(
                topic: request.topic,
                requestId: request.requestId,
                context: "request expired"
            )
            emit(.sessionRequestExpired(topic: request.topic, requestId: request.requestId))
        }
    }

    func handleSessionSettled(_ rawSession: Session) {
        let session = sessionRepository.enrichSession(
            WalletConnectSession(
                topic: rawSession.topic,
                dapp: WalletConnectDapp(metadata: rawSession.peer),
                walletId: nil,
                sourceState: .unknown,
                chains: WalletConnectSessionNamespaceBuilder.chains(from: rawSession.namespaces)
            )
        )
        if session.walletId == nil {
            settlingSessionTopics.insert(session.topic)
        }
        emit(.sessionSettled(session))
        logSessionSettled(session)
    }

    func handleSessionDeleted(topic: String) {
        settlingSessionTopics.remove(topic)
        requestCoordinator.removePendingRequests(topic: topic)
        autoRejectService.cancelRequests(
            topic: topic,
            context: "session deleted"
        )
        do {
            try removeStoredSession(topic: topic, context: "session deleted")
        } catch {
            emit(.error(WalletConnectErrorEvent(topic: topic, message: "\(error)")))
        }
        emit(.sessionDeleted(topic: topic))
        logSessionDeleted(topic: topic)
    }

    func handleSwitchEthereumChainRequest(
        _ request: WalletConnectSessionRequest,
        targetChain: WalletConnectChain
    ) async {
        guard network.sessionSupports(
            topic: request.topic,
            chain: targetChain,
            method: .walletSwitchEthereumChain,
            event: "chainChanged"
        ) else {
            await rejectSwitchEthereumChainRequest(
                request,
                reason: .unsupportedChain,
                message: "WalletConnect session does not support \(targetChain.caip2)"
            )
            return
        }

        do {
            try await requestCoordinator.approve(
                id: request.id,
                topic: request.topic,
                result: .null
            )
        } catch {
            emit(.error(WalletConnectErrorEvent(topic: request.topic, message: "\(error)")))
            return
        }

        do {
            try await network.emitChainChanged(
                topic: request.topic,
                chain: targetChain
            )
        } catch {
            emit(.error(WalletConnectErrorEvent(topic: request.topic, message: "\(error)")))
        }
    }

    func rejectSwitchEthereumChainRequest(
        _ request: WalletConnectSessionRequest,
        reason: WalletConnectRequestRejectionReason,
        message: String
    ) async {
        do {
            try await requestCoordinator.reject(
                id: request.id,
                topic: request.topic,
                reason: reason
            )
        } catch {
            emit(.error(WalletConnectErrorEvent(topic: request.topic, message: "\(error)")))
            return
        }
        emit(.error(WalletConnectErrorEvent(topic: request.topic, message: message)))
    }
}

private extension WalletConnectServiceImplementation {
    func finishApprovedProposal(
        _ approvedProposal: WalletConnectApprovedProposal
    ) async throws(WalletConnectSessionApprovalError) {
        do {
            try sessionRepository.recordApprovedSession(
                approvedProposal.session,
                proposal: approvedProposal.proposal,
                walletId: approvedProposal.walletId
            )
        } catch {
            let approvalError = WalletConnectSessionApprovalError.storage(message: error.logDescription)
            Log.walletConnect.w(
                "approved proposal persistence failed",
                error: approvalError,
                extraInfo: [
                    "proposalId": approvedProposal.proposal.id,
                ]
            )
            emit(.error(WalletConnectErrorEvent(topic: approvedProposal.session.topic, message: "\(error)")))
            settlingSessionTopics.remove(approvedProposal.session.topic)
            await disconnectApprovedSessionAfterStorageFailure(topic: approvedProposal.session.topic)
            proposalCoordinator.clear(
                id: approvedProposal.proposal.id,
                pairingTopic: approvedProposal.proposal.pairingTopic
            )
            throw approvalError
        }

        settlingSessionTopics.remove(approvedProposal.session.topic)
        emit(.sessionSettled(sessionRepository.enrichSession(approvedProposal.session)))
        proposalCoordinator.clear(
            id: approvedProposal.proposal.id,
            pairingTopic: approvedProposal.proposal.pairingTopic
        )
    }

    func autoReject(_ action: WalletConnectSessionRequestAutoReject) {
        autoRejectService.rejectRequest(
            topic: action.topic,
            requestId: action.requestId,
            context: action.context,
            error: action.error
        )
    }

    func disconnectOrphanSessions(
        topics: [String],
        context: String
    ) async -> Set<String> {
        var unresolvedTopics = Set<String>()
        for topic in topics {
            let disconnected = await disconnectOrphanSession(topic: topic, context: context)
            if !disconnected {
                unresolvedTopics.insert(topic)
            }
        }
        return unresolvedTopics
    }

    func disconnectOrphanSession(
        topic: String,
        context: String
    ) async -> Bool {
        do {
            try await network.disconnect(topic: topic)
            clearDisconnectedSessionRuntimeState(topic: topic, context: context)
            return true
        } catch {
            guard shouldTreatDisconnectFailureAsMissingSession(error, topic: topic) else {
                Log.walletConnect.w(
                    "orphan session disconnect failed",
                    error: error,
                    extraInfo: [
                        "context": context,
                    ]
                )
                emit(.error(WalletConnectErrorEvent(topic: topic, message: "\(error)")))
                return false
            }
            clearDisconnectedSessionRuntimeState(topic: topic, context: context)
            return true
        }
    }

    func clearDisconnectedSessionRuntimeState(topic: String, context: String) {
        settlingSessionTopics.remove(topic)
        requestCoordinator.removePendingRequests(topic: topic)
        autoRejectService.cancelRequests(topic: topic, context: context)
    }

    func removeStoredSession(
        topic: String,
        context: String
    ) throws(WalletConnectResponseError) {
        do {
            try sessionRepository.removeSession(
                topic: topic,
                context: context
            )
        } catch {
            throw .storage(message: error.logDescription)
        }
    }

    func shouldTreatDisconnectFailureAsMissingSession(
        _ error: WalletConnectResponseError,
        topic: String
    ) -> Bool {
        if error.isMissingSession {
            return true
        }
        guard !error.isRetryableDeliveryFailure else {
            return false
        }
        return !network.activeSessions().contains { $0.topic == topic }
    }

    func disconnectApprovedSessionAfterStorageFailure(topic: String) async {
        _ = await disconnectOrphanSession(
            topic: topic,
            context: "approved session storage failure"
        )
    }

    func sessionContext(topic: String) -> WalletConnectSessionContextLookup {
        let sdkSessions = network.activeSessions()
        guard let sdkSession = sdkSessions.first(where: { $0.topic == topic }) else {
            return .missingDapp
        }
        guard let storedSession = sessionRepository.storedSession(topic: topic) else {
            return .missingWalletMapping
        }
        return .found(
            WalletConnectSessionContext(
                dapp: sdkSession.dapp,
                walletId: storedSession.walletId,
                sourceState: storedSession.sourceState
            )
        )
    }

    func emit(_ event: WalletConnectServiceEvent) {
        eventsMulticast.emit(event)
    }
}

private func logWalletConnectConfigurationFailure(_ error: Error) {
    Log.e("WalletConnect: failed to configure service", error: error)
}

private func pairingError(_ error: WalletConnectConfigurationError) -> WalletConnectPairingError {
    switch error {
    case .invalidRedirect:
        return .sdk(message: error.logDescription)
    case let .sdk(message):
        return .sdk(message: message)
    }
}

private func logSessionProposalReceived(_ proposal: WalletConnectSessionProposal) {
    Log.walletConnect.i("session proposal received", extraInfo: [
        "proposalId": proposal.id,
        "validation": "\(proposal.validation)",
        "chains": proposal.namespaces.flatMap(\.chains).map(\.caip2).sorted().pretty.string,
        "methods": proposal.namespaces.flatMap(\.methods).map(\.rawValue).sorted().pretty.string,
    ])
}

private func logDuplicatePairingIgnored(pairingTopic _: String, source: DappConnectionSource) {
    Log.walletConnect.i("duplicate pending pairing ignored", extraInfo: [
        "source": "\(source)",
    ])
}

private func logSessionProposalExpired(_ proposal: WalletConnectSessionProposal) {
    Log.walletConnect.i("session proposal expired", extraInfo: [
        "proposalId": proposal.id,
    ])
}

private func logSessionSettled(_: WalletConnectSession) {
    Log.walletConnect.i("session settled")
}

private func logSessionDeleted(topic _: String) {
    Log.walletConnect.i("session deleted")
}
