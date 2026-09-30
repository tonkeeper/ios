import Foundation
import KeeperCore
import TKCoordinator
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

enum WalletConnectEventsLoop {
    case running(
        readiness: Task<AsyncStream<WalletConnectServiceEvent>?, Never>,
        events: Task<Void, Never>
    )

    func waitUntilReady() async {
        switch self {
        case let .running(readiness, _):
            _ = await readiness.value
        }
    }

    func cancel() {
        switch self {
        case let .running(readiness, events):
            readiness.cancel()
            events.cancel()
        }
    }
}

extension MainCoordinator {
    func setupWalletConnectIfNeeded() {
        guard walletConnectState.eventsLoop == nil else { return }

        let readiness = Task { [weak self] () -> AsyncStream<WalletConnectServiceEvent>? in
            guard let self else {
                return nil
            }
            let walletConnectAssembly = keeperCoreMainAssembly.walletConnectAssembly
            let service = await walletConnectAssembly.walletConnectService
            let walletsSynchronizer = await walletConnectAssembly.walletConnectWalletsSynchronizer
            let eventsStream = await service.startedEvents()
            await walletsSynchronizer.startAutoDisconnect()
            return eventsStream
        }

        let events = Task { [weak self, readiness] in
            guard let eventsStream = await readiness.value else {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            let store: WalletConnectSessionsStore?
            if let self {
                store = keeperCoreMainAssembly.storesAssembly.walletConnectSessionsStore(
                    walletConnectService: await keeperCoreMainAssembly.walletConnectAssembly.walletConnectService
                )
                store?.refresh()
            }
            for await event in eventsStream {
                if Task.isCancelled { return }
                await self?.handleWalletConnectEvent(event)
            }
        }

        walletConnectState.eventsLoop = .running(
            readiness: readiness,
            events: events
        )
    }

    func handleWalletConnectDeeplink(_ payload: WalletConnectDeeplink) -> Bool {
        switch walletConnectAvailability.deeplinkDecision {
        case .activeWalletNotMultichain:
            Log.walletConnect.i("WalletConnect deeplink ignored: active wallet is not multichain")
            ToastPresenter.hideAll()
            ToastPresenter.showToast(
                configuration: ToastPresenter.Configuration(
                    title: "Switch to a multichain wallet to connect"
                )
            )
            return true
        case .pair:
            break
        }

        ToastPresenter.hideAll()
        setupWalletConnectIfNeeded()

        Task { [weak self] in
            guard let self else { return }
            await walletConnectState.eventsLoop?.waitUntilReady()
            guard !Task.isCancelled else { return }
            let service = await keeperCoreMainAssembly.walletConnectAssembly.walletConnectService
            do {
                try await service.pair(
                    uri: payload.uri,
                    source: payload.source
                )
            } catch {
                return await MainActor.run {
                    self.clearWalletConnectPairingLoaders()
                    self.showWalletConnectError(error)
                }
            }
        }
        return true
    }
}

private extension MainCoordinator {
    var walletConnectAvailability: WalletConnectAvailability {
        WalletConnectAvailability(
            isActiveWalletMultichain: isActiveWalletMultichain
        )
    }

    @MainActor
    func handleWalletConnectEvent(_ event: WalletConnectServiceEvent) async {
        switch event {
        case let .pairingStarted(pairingTopic, _):
            handleWalletConnectPairingStarted(pairingTopic: pairingTopic)
        case let .pairingExpired(pairingTopic, source):
            finishWalletConnectPairing(pairingTopic: pairingTopic)
            showWalletConnectError("Session proposal expired")
            Log.walletConnect.i("WalletConnect pairing expired", extraInfo: [
                "source": "\(source)",
            ])
        case let .sessionProposal(proposal):
            finishWalletConnectPairing(pairingTopic: proposal.pairingTopic)
            await handleWalletConnectProposal(proposal)
        case let .sessionProposalExpired(proposal):
            finishWalletConnectPairing(pairingTopic: proposal.pairingTopic)
            dismissExpiredWalletConnectProposal(
                id: proposal.id,
                pairingTopic: proposal.pairingTopic
            )
            showWalletConnectError("Session proposal expired")
            Log.walletConnect.i("WalletConnect proposal expired", extraInfo: [
                "proposalId": proposal.id,
            ])
        case let .sessionRequest(request):
            await handleWalletConnectRequest(request)
        case let .sessionRequestExpired(topic, requestId):
            dismissExpiredWalletConnectRequest(id: requestId, topic: topic)
            showWalletConnectError("Request expired")
        case .sessionSettled:
            break
        case let .sessionDeleted(topic):
            dismissWalletConnectRequests(topic: topic)
        case let .error(error):
            clearWalletConnectPairingLoaders()
            showWalletConnectError(error.message)
        }
    }

    @MainActor
    func handleWalletConnectPairingStarted(pairingTopic: String) {
        walletConnectState.pairingTopics.insert(pairingTopic)
        ToastPresenter.hideAll()
        ToastPresenter.showToast(configuration: .loading)
    }

    @MainActor
    func finishWalletConnectPairing(pairingTopic: String) {
        guard walletConnectState.pairingTopics.remove(pairingTopic) != nil else {
            return
        }
        if walletConnectState.pairingTopics.isEmpty {
            ToastPresenter.hideToast()
        }
    }

    @MainActor
    func clearWalletConnectPairingLoaders() {
        guard !walletConnectState.pairingTopics.isEmpty else {
            return
        }
        walletConnectState.pairingTopics.removeAll()
        ToastPresenter.hideToast()
    }

    @MainActor
    func handleWalletConnectProposal(_ proposal: WalletConnectSessionProposal) async {
        await enqueueWalletConnectPresentation(.proposal(proposal))
    }

    @MainActor
    func handleWalletConnectRequest(_ request: WalletConnectSessionRequest) async {
        await enqueueWalletConnectPresentation(.request(request))
    }

    @MainActor
    func enqueueWalletConnectPresentation(_ item: WalletConnectPresentationItem) async {
        guard let itemToPresent = walletConnectState.presentationQueue.enqueue(item) else {
            return
        }
        await presentWalletConnectPresentation(itemToPresent)
    }

    @MainActor
    func presentWalletConnectPresentation(_ item: WalletConnectPresentationItem) async {
        guard walletConnectState.presentationQueue.isActive(item.key) else {
            return
        }

        let didPresent: Bool
        switch item {
        case let .proposal(proposal):
            didPresent = await presentWalletConnectProposal(proposal)
        case let .request(request):
            didPresent = await presentWalletConnectRequest(request)
        }

        guard walletConnectState.presentationQueue.isActive(item.key) else {
            return
        }
        if !didPresent {
            finishWalletConnectPresentation(key: item.key)
        }
    }

    @MainActor
    func finishWalletConnectPresentation(key: WalletConnectPresentationKey) {
        guard let nextItem = walletConnectState.presentationQueue.finish(key) else {
            return
        }
        Task { [weak self] in
            await self?.presentWalletConnectPresentation(nextItem)
        }
    }

    @MainActor
    func presentWalletConnectProposal(_ proposal: WalletConnectSessionProposal) async -> Bool {
        let key = WalletConnectProposalKey(proposal)
        let service = await keeperCoreMainAssembly.walletConnectAssembly.walletConnectService
        guard walletConnectState.presentationQueue.isActive(.proposal(key)) else {
            return false
        }

        let wallet: Wallet
        let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore
        guard let multichainWallet = walletsStore.preferredMultichainWallet else {
            Log.walletConnect.w(
                "proposal presentation skipped: multichain wallet missing",
                error: WalletConnectPresentationError.multichainWalletMissing,
                extraInfo: ["proposalId": proposal.id]
            )
            rejectWalletConnectProposal(
                id: proposal.id,
                service: service,
                context: "missing multichain wallet"
            )
            showWalletConnectError("No multichain wallet")
            return false
        }
        wallet = multichainWallet

        let walletConnectProposal = WalletConnectProposal(
            proposal: proposal,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: ViewControllerRouter(rootViewController: router.rootViewController)
        )

        var shouldHandleDeliveredProposalResponse = false
        walletConnectProposal.didReject = {
            do {
                try await service.rejectProposal(id: proposal.id)
                shouldHandleDeliveredProposalResponse = true
            } catch {
                Log.walletConnect.w(
                    "proposal rejection after user action failed",
                    error: error,
                    extraInfo: ["proposalId": proposal.id]
                )
                throw error
            }
        }
        walletConnectProposal.didApprove = { wallet in
            try await service.approveProposal(
                id: proposal.id,
                wallet: wallet
            )
            shouldHandleDeliveredProposalResponse = true
        }
        walletConnectProposal.didDeliverResponse = { [weak self] in
            guard shouldHandleDeliveredProposalResponse else { return }
            self?.handleDeliveredWalletConnectResponse(
                dapp: proposal.dapp,
                source: proposal.source
            )
        }
        walletConnectProposal.didFinish = { [weak self] coordinator in
            self?.walletConnectState.proposalCoordinators[key] = nil
            self?.removeChild(coordinator)
            self?.finishWalletConnectPresentation(key: .proposal(key))
        }

        walletConnectState.proposalCoordinators[key] = walletConnectProposal
        addChild(walletConnectProposal)
        walletConnectProposal.start()
        return true
    }

    @MainActor
    func presentWalletConnectRequest(_ request: WalletConnectSessionRequest) async -> Bool {
        let key = WalletConnectRequestKey(request)
        let service = await keeperCoreMainAssembly.walletConnectAssembly.walletConnectService
        guard walletConnectState.presentationQueue.isActive(.request(key)) else {
            return false
        }

        let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore

        guard let walletId = request.walletId else {
            Log.walletConnect.w(
                "request presentation skipped: stored wallet mapping missing",
                error: WalletConnectPresentationError.walletMappingMissing,
                extraInfo: walletConnectRequestLogInfo(request)
            )
            return false
        }

        guard let wallet = walletsStore.getWallet(id: walletId) else {
            Log.walletConnect.w(
                "request presentation skipped: mapped wallet deleted",
                error: WalletConnectPresentationError.mappedWalletMissing,
                extraInfo: walletConnectRequestLogInfo(request)
            )
            await cleanupWalletConnectRequestForDeletedWallet(
                request,
                walletId: walletId,
                service: service
            )
            return false
        }

        guard case .regular = wallet.kind else {
            rejectWalletConnectRequest(
                id: request.id,
                topic: request.topic,
                service: service,
                context: "unsupported wallet kind"
            )
            showWalletConnectError("Wallet type is not supported for WalletConnect")
            return false
        }

        let walletConnectRequest = WalletConnectRequest(
            request: request,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: ViewControllerRouter(rootViewController: router.rootViewController)
        )
        var shouldHandleDeliveredRequestResponse = false

        walletConnectRequest.didReject = {
            do {
                try await service.rejectRequest(id: request.id, topic: request.topic)
                shouldHandleDeliveredRequestResponse = true
            } catch {
                Log.walletConnect.w(
                    "request rejection after user action failed",
                    error: error,
                    extraInfo: walletConnectRequestLogInfo(request)
                )
                throw error
            }
        }
        walletConnectRequest.didApprove = { [weak self] approvalState in
            guard let self else { return }
            try await self.approveWalletConnectRequest(
                request,
                wallet: wallet,
                approvalState: approvalState
            )
            shouldHandleDeliveredRequestResponse = true
        }
        walletConnectRequest.didDeliverResponse = { [weak self] in
            guard shouldHandleDeliveredRequestResponse else { return }
            self?.handleDeliveredWalletConnectResponse(
                dapp: request.dapp,
                source: request.source
            )
        }
        walletConnectRequest.didFinish = { [weak self] coordinator in
            self?.walletConnectState.requestCoordinators[key] = nil
            self?.removeChild(coordinator)
            self?.finishWalletConnectPresentation(key: .request(key))
        }

        walletConnectState.requestCoordinators[key] = walletConnectRequest
        addChild(walletConnectRequest)
        walletConnectRequest.start()
        return true
    }

    func approveWalletConnectRequest(
        _ request: WalletConnectSessionRequest,
        wallet: Wallet,
        approvalState: WalletConnectRequestApprovalState
    ) async throws {
        let service = await keeperCoreMainAssembly.walletConnectAssembly.walletConnectService

        let response: WalletConnectResponseValue
        if let cachedResponse = approvalState.cachedResponse() {
            response = cachedResponse
        } else {
            do {
                response = try await signWalletConnectRequest(
                    request,
                    wallet: wallet
                )
                approvalState.cacheResponse(response)
            } catch {
                Log.walletConnect.w(
                    "request signing failed",
                    error: error,
                    extraInfo: walletConnectRequestLogInfo(request)
                )
                do {
                    try await service.rejectRequest(
                        id: request.id,
                        topic: request.topic,
                        reason: error.walletConnectRequestRejectionReason
                    )
                } catch let rejectError {
                    Log.walletConnect.w(
                        "request rejection after signing failure failed",
                        error: rejectError,
                        extraInfo: walletConnectRequestLogInfo(request)
                    )
                    if rejectError.isRetryableDeliveryFailure {
                        throw WalletConnectRequestDeliveryRetryError.reject(rejectError)
                    }
                    throw rejectError
                }
                throw error
            }
        }

        do {
            try await service.approveRequest(
                id: request.id,
                topic: request.topic,
                result: response
            )
        } catch {
            Log.walletConnect.w(
                "request approval delivery failed",
                error: error,
                extraInfo: walletConnectRequestLogInfo(request)
            )
            if error.isRetryableDeliveryFailure {
                throw WalletConnectRequestDeliveryRetryError.approve(error)
            }
            throw error
        }
    }

    func signWalletConnectRequest(
        _ request: WalletConnectSessionRequest,
        wallet: Wallet
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        let signingService = keeperCoreMainAssembly.walletConnectAssembly.walletConnectSigningService
        let passcodeProvider: () async -> String? = { [weak self] in
            guard let self else { return nil }
            return await PasscodeInputCoordinator.getPasscode(
                parentCoordinator: self,
                parentRouter: self.router,
                mnemonicAccess: self.keeperCoreMainAssembly.mnemonicAccess,
                securityStore: self.keeperCoreMainAssembly.storesAssembly.securityStore,
                analyticsProvider: self.coreAssembly.analyticsProvider
            )
        }

        return try await signingService.sign(
            passcodeProvider: passcodeProvider,
            wallet: wallet,
            request: request
        )
    }

    @MainActor
    func handleDeliveredWalletConnectResponse(
        dapp: WalletConnectDapp,
        source: DappConnectionSource?
    ) {
        switch WalletConnectRedirectRouter.RoutingPolicy(source: source) {
        case .nativeDapp:
            WalletConnectRedirectRouter.goBackIfNeeded(to: dapp, source: source)
        case .qr, .browser, .deeplink:
            break
        }
    }

    @MainActor
    func showWalletConnectError(_ error: Error) {
        showWalletConnectError((error as? LocalizedError)?.errorDescription ?? "\(error)")
    }

    @MainActor
    func showWalletConnectError(_ message: String) {
        ToastPresenter.showToast(
            configuration: ToastPresenter.Configuration(
                title: message
            )
        )
    }

    @MainActor
    func dismissExpiredWalletConnectRequest(id: String, topic: String) {
        let key = WalletConnectRequestKey(id: id, topic: topic)
        let presentationKey = WalletConnectPresentationKey.request(key)

        if walletConnectState.presentationQueue.removeQueued(presentationKey) {
            return
        }

        guard walletConnectState.presentationQueue.isActive(presentationKey) else {
            return
        }

        guard let coordinator = walletConnectState.requestCoordinators[key] else {
            finishWalletConnectPresentation(key: presentationKey)
            return
        }
        guard coordinator.matchesRequest(id: id, topic: topic) else {
            return
        }
        coordinator.dismissAfterRequestExpired()
    }

    @MainActor
    func dismissExpiredWalletConnectProposal(id: String, pairingTopic: String) {
        let key = WalletConnectProposalKey(id: id, pairingTopic: pairingTopic)
        let presentationKey = WalletConnectPresentationKey.proposal(key)

        if walletConnectState.presentationQueue.removeQueued(presentationKey) {
            return
        }

        guard walletConnectState.presentationQueue.isActive(presentationKey) else {
            return
        }

        guard let coordinator = walletConnectState.proposalCoordinators[key] else {
            finishWalletConnectPresentation(key: presentationKey)
            return
        }
        guard coordinator.matchesProposal(id: id, pairingTopic: pairingTopic) else {
            return
        }
        coordinator.dismissAfterProposalExpired()
    }

    @MainActor
    func dismissWalletConnectRequests(topic: String) {
        walletConnectState.presentationQueue.removeQueuedRequests(topic: topic)

        guard case let .request(key) = walletConnectState.presentationQueue.activeKey,
              key.topic == topic
        else {
            return
        }

        dismissExpiredWalletConnectRequest(id: key.id, topic: key.topic)
    }

    func rejectWalletConnectProposal(
        id: String,
        service: any WalletConnectService,
        context: String
    ) {
        Task {
            do {
                try await service.rejectProposal(id: id)
            } catch {
                Log.walletConnect.w(
                    "proposal rejection failed",
                    error: error,
                    extraInfo: [
                        "proposalId": id,
                        "context": context,
                    ]
                )
            }
        }
    }

    func rejectWalletConnectRequest(
        id: String,
        topic: String,
        service: any WalletConnectService,
        context: String
    ) {
        Task {
            do {
                try await service.rejectRequest(id: id, topic: topic)
            } catch {
                Log.walletConnect.w(
                    "request rejection failed",
                    error: error,
                    extraInfo: [
                        "requestId": id,
                        "context": context,
                    ]
                )
            }
        }
    }

    func cleanupWalletConnectRequestForDeletedWallet(
        _ request: WalletConnectSessionRequest,
        walletId: String,
        service: any WalletConnectService
    ) async {
        do {
            try await service.rejectRequest(id: request.id, topic: request.topic)
        } catch {
            Log.walletConnect.w(
                "request rejection for deleted wallet failed",
                error: error,
                extraInfo: walletConnectRequestLogInfo(request)
            )
        }

        do {
            try await service.disconnect(topic: request.topic)
        } catch {
            Log.walletConnect.w(
                "stale session disconnect failed",
                error: error,
                extraInfo: walletConnectRequestLogInfo(request)
            )
            do {
                try await service.removeLocalSession(topic: request.topic)
            } catch {
                Log.walletConnect.w(
                    "stale local session removal failed",
                    error: error,
                    extraInfo: walletConnectRequestLogInfo(request)
                )
            }
        }
    }
}

private enum WalletConnectPresentationError: LoggableError {
    case multichainWalletMissing
    case walletMappingMissing
    case mappedWalletMissing

    var logDescription: String {
        switch self {
        case .multichainWalletMissing:
            return "type=WalletConnectPresentationError, case=multichainWalletMissing"
        case .walletMappingMissing:
            return "type=WalletConnectPresentationError, case=walletMappingMissing"
        case .mappedWalletMissing:
            return "type=WalletConnectPresentationError, case=mappedWalletMissing"
        }
    }
}

private func walletConnectRequestLogInfo(
    _ request: WalletConnectSessionRequest
) -> [String: String] {
    [
        "requestId": request.id,
        "method": request.method.rawValue,
        "chain": request.chain.caip2,
    ]
}

private extension WalletsStore {
    /// Seeds the proposal screen, whose own wallet picker is restricted to multichain wallets and
    /// falls back the same way. A pairing normally starts while a multichain wallet is active; the
    /// fallback only covers the wallet being switched between pairing and the proposal arriving.
    var preferredMultichainWallet: Wallet? {
        if let activeWallet = try? activeWallet,
           activeWallet.isMultichain
        {
            return activeWallet
        }

        return wallets.first(where: \.isMultichain)
    }
}
