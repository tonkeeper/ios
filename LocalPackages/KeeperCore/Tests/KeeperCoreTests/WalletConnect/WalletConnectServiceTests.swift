@preconcurrency import Commons
@testable import KeeperCore
import KeeperCoreComponents
import ReownWalletKit
import TonSwift
import XCTest

private let walletConnectSessionCreatedAt = Date(timeIntervalSince1970: 1_700_000_000)

final class WalletConnectServiceTests: XCTestCase {
    func testEventsAreMulticastStreams() async throws {
        let context = await makeServiceContext()

        let first = await context.service.events()
        let second = await context.service.events()
        await context.service.start()

        let proposal = try makeProposalContext()
        async let firstEvent = nextEvent(first)
        async let secondEvent = nextEvent(second)
        try await Task.sleep(nanoseconds: 1_000_000)
        await context.eventStream.emit(.proposalReceived(proposal))

        let firstResult = await firstEvent
        let secondResult = await secondEvent
        XCTAssertEqual(firstResult, .sessionProposal(proposal.proposal(source: .deeplink)))
        XCTAssertEqual(secondResult, .sessionProposal(proposal.proposal(source: .deeplink)))
    }

    func testPairNormalizesURIAndAppliesSourceToNextProposal() async throws {
        let context = await makeServiceContext()
        let events = await context.service.events()

        try await context.service.pair(
            uri: "https://app.tonkeeper.com/wc?uri=wc%3Apairing%402%3Frelay-protocol%3Dirn%26symKey%3Dabc",
            source: .browser
        )

        let pairURIs = await context.network.pairURIs()
        XCTAssertEqual(pairURIs, ["wc:pairing@2?relay-protocol=irn&symKey=abc"])
        let configuredCalls = await context.network.configuredCalls()
        XCTAssertEqual(configuredCalls, 1)

        let pairingStartedEvent = await nextEvent(events)
        XCTAssertEqual(pairingStartedEvent, .pairingStarted(pairingTopic: "pairing", source: .browser))

        let proposal = try makeProposalContext(pairingTopic: "pairing")
        let proposalEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(proposal))
        }

        XCTAssertEqual(proposalEvent, .sessionProposal(proposal.proposal(source: .browser)))
    }

    func testDuplicateSamePairingLinkKeepsOriginalSourceAndLoaderState() async throws {
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                pairResults: [
                    .success(()),
                    .failure(.sdk(message: "pairing already exists")),
                ]
            ),
            pairingProposalTimeoutNanoseconds: 1_000_000_000
        )
        let events = await context.service.events()

        try await context.service.pair(
            uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
            source: .browser
        )

        let pairingStartedEvent = await nextEvent(events)
        XCTAssertEqual(pairingStartedEvent, .pairingStarted(pairingTopic: "pairing", source: .browser))

        let duplicateEvents = await context.service.events()
        try await context.service.pair(
            uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
            source: .deeplink
        )

        let pairURIs = await context.network.pairURIs()
        XCTAssertEqual(pairURIs, ["wc:pairing@2?relay-protocol=irn&symKey=abc"])
        let duplicateEvent = await nextEvent(duplicateEvents, timeout: 50_000_000)
        XCTAssertNil(duplicateEvent)

        let proposal = try makeProposalContext(pairingTopic: "pairing")
        let proposalEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(proposal))
        }

        XCTAssertEqual(proposalEvent, .sessionProposal(proposal.proposal(source: .browser)))
        let nextEvent = await nextEvent(events, timeout: 50_000_000)
        XCTAssertNil(nextEvent)
    }

    func testAcceptedPairingWithoutProposalEmitsPairingExpiredWithinConfiguredBudget() async throws {
        let context = await makeServiceContext(pairingProposalTimeoutNanoseconds: 1_000_000)
        let events = await context.service.events()

        try await context.service.pair(
            uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
            source: .browser
        )

        let pairingStartedEvent = await nextEvent(events)
        XCTAssertEqual(pairingStartedEvent, .pairingStarted(pairingTopic: "pairing", source: .browser))

        let pairingExpiredEvent = await nextEvent(events)
        XCTAssertEqual(pairingExpiredEvent, .pairingExpired(pairingTopic: "pairing", source: .browser))
    }

    func testDefaultPairingProposalTimeoutMatchesInactivePairingExpiry() {
        XCTAssertEqual(
            WalletConnectPairingTimeouts.defaultProposalNanoseconds,
            300_000_000_000
        )
    }

    func testPairingSourceSurvivesLatencyBudget() async throws {
        let now = Date(timeIntervalSince1970: 1000)
        let sourceStore = makePairingSourceStore()
        let coordinator = await WalletConnectPairingCoordinator(
            eventSink: MulticastAsyncStream<WalletConnectServiceEvent>(),
            sourceStore: sourceStore,
            pairingProposalTimeoutNanoseconds: WalletConnectPairingTimeouts.defaultProposalNanoseconds,
            now: { now }
        )

        _ = try await coordinator.preparePairing(
            uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
            source: .browser
        )

        let storedSource = try XCTUnwrap(sourceStore.load()["pairing"])
        XCTAssertEqual(storedSource.source, .browser)
        XCTAssertEqual(
            storedSource.expiresAt.timeIntervalSince(now),
            300,
            accuracy: 1
        )
    }

    func testProposalCancelsPairingExpiration() async throws {
        let context = await makeServiceContext(pairingProposalTimeoutNanoseconds: 50_000_000)
        let events = await context.service.events()

        try await context.service.pair(
            uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
            source: .browser
        )
        _ = await nextEvent(events)

        let proposal = try makeProposalContext(pairingTopic: "pairing")
        let proposalEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(proposal))
        }

        XCTAssertEqual(proposalEvent, .sessionProposal(proposal.proposal(source: .browser)))
        let nextEvent = await nextEvent(events, timeout: 100_000_000)
        XCTAssertNil(nextEvent)
    }

    func testProposalAfterRelaunchUsesPersistedPairingSource() async throws {
        let pairingSourceStore = makePairingSourceStore()
        let initialContext = await makeServiceContext(pairingSourceStore: pairingSourceStore)
        let initialEvents = await initialContext.service.events()

        try await initialContext.service.pair(
            uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
            source: .browser
        )
        _ = await nextEvent(initialEvents)

        let relaunchedContext = await makeServiceContext(pairingSourceStore: pairingSourceStore)
        let relaunchedEvents = await relaunchedContext.service.events()
        await relaunchedContext.service.start()

        let proposal = try makeProposalContext(pairingTopic: "pairing")
        let proposalEvent = await nextEventAfterEmitting(relaunchedEvents) {
            await relaunchedContext.eventStream.emit(.proposalReceived(proposal))
        }

        XCTAssertEqual(proposalEvent, .sessionProposal(proposal.proposal(source: .browser)))
    }

    func testStartHydratesPendingProposalAfterRelaunchWithPersistedPairingSource() async throws {
        let pairingSourceStore = makePairingSourceStore()
        let initialContext = await makeServiceContext(pairingSourceStore: pairingSourceStore)
        let initialEvents = await initialContext.service.events()

        try await initialContext.service.pair(
            uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
            source: .browser
        )
        _ = await nextEvent(initialEvents)

        let proposal = try makeProposalContext(pairingTopic: "pairing")
        let relaunchedContext = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                pendingProposalsResult: [proposal]
            ),
            pairingSourceStore: pairingSourceStore
        )

        let events = await relaunchedContext.service.startedEvents()
        let proposalEvent = await nextEvent(events)

        XCTAssertEqual(proposalEvent, .sessionProposal(proposal.proposal(source: .browser)))
    }

    func testStartDeduplicatesHydratedAndLiveProposal() async throws {
        let proposal = try makeProposalContext(pairingTopic: "pairing")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                pendingProposalsResult: [proposal]
            )
        )

        let events = await context.service.startedEvents()
        let hydratedEvent = await nextEvent(events)
        XCTAssertEqual(hydratedEvent, .sessionProposal(proposal.proposal(source: .deeplink)))

        let duplicateEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(proposal))
        }
        XCTAssertNil(duplicateEvent)
    }

    func testStartHydratesPendingRequestAfterRelaunch() async throws {
        let session = makeSession(topic: "session-topic")
        let store = makeSessionStore()
        try store.save([
            "session-topic": WalletConnectStoredSession(
                walletId: "wallet",
                source: .browser,
                createdAt: walletConnectSessionCreatedAt
            ),
        ])
        let request = try makePersonalSignRequest(topic: "session-topic", id: "request")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                pendingRequestsResult: [request]
            ),
            store: store
        )

        let events = await context.service.startedEvents()
        let requestEvent = await nextEvent(events)

        guard case let .sessionRequest(sessionRequest) = requestEvent else {
            XCTFail("Expected hydrated session request event")
            return
        }
        XCTAssertEqual(sessionRequest.id, "request")
        XCTAssertEqual(sessionRequest.topic, "session-topic")
        XCTAssertEqual(sessionRequest.walletId, "wallet")
        XCTAssertEqual(sessionRequest.source, .browser)

        let duplicateEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }
        XCTAssertNil(duplicateEvent)
    }

    func testDuplicateLiveProposalWithSamePairingTopicAndIdIsIgnored() async throws {
        let context = await makeServiceContext()
        let events = await context.service.events()
        await context.service.start()

        let proposal = try makeProposalContext(id: "proposal", pairingTopic: "pairing")
        let proposalEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(proposal))
        }
        XCTAssertEqual(proposalEvent, .sessionProposal(proposal.proposal(source: .deeplink)))

        let duplicateEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(proposal))
        }
        XCTAssertNil(duplicateEvent)
    }

    func testProposalWithSamePairingTopicAndIdCanBeReceivedAgainAfterClear() async throws {
        let network = await WalletConnectWalletKitClientMock()
        let coordinator = await WalletConnectSessionProposalCoordinator(
            network: network
        )
        let proposal = try makeProposalContext(id: "proposal", pairingTopic: "pairing")

        let firstProposal = await coordinator.receive(proposal, source: .browser)
        XCTAssertEqual(firstProposal?.id, "proposal")

        await coordinator.clear(id: proposal.id, pairingTopic: proposal.pairingTopic)

        let secondProposal = await coordinator.receive(proposal, source: .browser)
        XCTAssertEqual(secondProposal?.id, "proposal")
    }

    func testProposalWithSamePairingTopicAndIdCanBeReceivedAgainAfterReject() async throws {
        let context = await makeServiceContext()
        let events = await context.service.events()
        await context.service.start()

        let proposal = try makeProposalContext(id: "proposal", pairingTopic: "pairing")
        let firstEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(proposal))
        }
        XCTAssertEqual(firstEvent, .sessionProposal(proposal.proposal(source: .deeplink)))

        try await context.service.rejectProposal(id: proposal.id)

        let secondEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(proposal))
        }
        XCTAssertEqual(secondEvent, .sessionProposal(proposal.proposal(source: .deeplink)))
    }

    func testProposalWithSamePairingTopicAndIdCanBeReceivedAgainAfterApprove() async throws {
        let context = await makeServiceContext()
        let events = await context.service.events()
        await context.service.start()

        let proposal = try makeProposalContext(id: "proposal", pairingTopic: "pairing")
        let firstEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(proposal))
        }
        XCTAssertEqual(firstEvent, .sessionProposal(proposal.proposal(source: .deeplink)))

        try await context.service.approveProposal(
            id: proposal.id,
            wallet: makeWallet()
        )
        guard case .sessionSettled = await nextEvent(events) else {
            XCTFail("Expected session settled event")
            return
        }

        let secondEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(proposal))
        }
        XCTAssertEqual(secondEvent, .sessionProposal(proposal.proposal(source: .deeplink)))
    }

    func testMultipleProposalsForSamePairingTopicUseSameSource() async throws {
        let context = await makeServiceContext()
        let events = await context.service.events()

        try await context.service.pair(
            uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
            source: .browser
        )
        _ = await nextEvent(events)

        let firstProposal = try makeProposalContext(id: "proposal-one", pairingTopic: "pairing")
        let firstProposalEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(firstProposal))
        }
        XCTAssertEqual(firstProposalEvent, .sessionProposal(firstProposal.proposal(source: .browser)))

        let secondProposal = try makeProposalContext(id: "proposal-two", pairingTopic: "pairing")
        let secondProposalEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(secondProposal))
        }
        XCTAssertEqual(secondProposalEvent, .sessionProposal(secondProposal.proposal(source: .browser)))
    }

    func testProposalsWithSameIdAndDifferentPairingTopicsApproveInReceiveOrder() async throws {
        let firstSession = makeSession(topic: "session-one")
        let secondSession = makeSession(topic: "session-two")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                approveProposalResults: [
                    .success(firstSession),
                    .success(secondSession),
                ]
            )
        )
        let events = await context.service.events()

        let firstProposal = try await receiveProposal(
            context: context,
            events: events,
            proposal: makeProposalContext(
                id: "proposal",
                pairingTopic: "pairing-one",
                requiredChains: [.eth],
                requiredMethods: [WalletConnectMethod.personalSign.rawValue]
            )
        )
        let secondProposal = try await receiveProposal(
            context: context,
            events: events,
            proposal: makeProposalContext(
                id: "proposal",
                pairingTopic: "pairing-two",
                requiredChains: [.tron],
                requiredMethods: [WalletConnectMethod.tronSignMessage.rawValue]
            )
        )
        let wallet = makeWallet(
            multichain: .multichain(.init(walletId: "wallet", addresses: [
                MultichainWalletAddress(chain: .eth, address: "0xabc"),
                MultichainWalletAddress(chain: .tron, address: "TXUEmLr"),
            ]))
        )

        try await context.service.approveProposal(id: firstProposal.id, wallet: wallet)
        try await context.service.approveProposal(id: secondProposal.id, wallet: wallet)

        let approveCalls = await context.network.approveProposalCalls()
        XCTAssertEqual(approveCalls.map(\.namespaceKeys), [["eip155"], ["tron"]])
        XCTAssertEqual(approveCalls.map(\.methods), [
            [WalletConnectMethod.personalSign.rawValue],
            [WalletConnectMethod.tronSignMessage.rawValue],
        ])
    }

    func testApprovedSessionAfterRelaunchReconcilesWithSDKAndRestoresSourceForRequests() async throws {
        let session = makeSession(topic: "session-topic")
        let store = makeSessionStore()
        let pairingSourceStore = makePairingSourceStore()
        let initialContext = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)]
            ),
            store: store,
            pairingSourceStore: pairingSourceStore
        )
        let initialEvents = await initialContext.service.events()

        try await initialContext.service.pair(
            uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
            source: .browser
        )
        _ = await nextEvent(initialEvents)
        let proposal = try await receiveProposal(
            context: initialContext,
            events: initialEvents,
            proposal: makeProposalContext(pairingTopic: "pairing")
        )
        try await initialContext.service.approveProposal(
            id: proposal.id,
            wallet: makeWallet()
        )
        XCTAssertEqual(store.load()["session-topic"], WalletConnectStoredSession(
            walletId: "wallet",
            source: .browser,
            createdAt: walletConnectSessionCreatedAt
        ))

        let relaunchedNetwork = await WalletConnectWalletKitClientMock(activeSessionsResult: [session])
        let relaunchedContext = await makeServiceContext(
            network: relaunchedNetwork,
            store: store,
            pairingSourceStore: pairingSourceStore
        )

        let activeSessions = await relaunchedContext.service.activeSessions()

        XCTAssertEqual(activeSessions, [
            WalletConnectSession(
                topic: "session-topic",
                dapp: makeDapp(),
                walletId: "wallet",
                source: .browser,
                createdAt: walletConnectSessionCreatedAt
            ),
        ])
        let disconnectTopics = await relaunchedNetwork.disconnectTopics()
        XCTAssertEqual(disconnectTopics, [])

        let events = await relaunchedContext.service.events()
        await relaunchedContext.service.start()
        let rawSession = try makeRawSession(topic: "session-topic")
        let settledEvent = await nextEventAfterEmitting(events) {
            await relaunchedContext.eventStream.emit(.sessionSettled(rawSession))
        }

        guard case let .sessionSettled(settledSession) = settledEvent else {
            XCTFail("Expected settled session event")
            return
        }
        XCTAssertEqual(settledSession.topic, "session-topic")
        XCTAssertEqual(settledSession.walletId, "wallet")
        XCTAssertEqual(settledSession.source, .browser)

        let request = try makePersonalSignRequest(topic: "session-topic")
        let requestEvent = await nextEventAfterEmitting(events) {
            await relaunchedContext.eventStream.emit(.requestReceived(request, context: nil))
        }

        guard case let .sessionRequest(sessionRequest) = requestEvent else {
            XCTFail("Expected session request event")
            return
        }
        XCTAssertEqual(sessionRequest.topic, "session-topic")
        XCTAssertEqual(sessionRequest.walletId, "wallet")
        XCTAssertEqual(sessionRequest.source, .browser)
    }

    func testFailedPairingRemovesSourceAndCancelsExpiration() async throws {
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                pairResults: [.failure(.sdk(message: "pair failed"))]
            ),
            pairingProposalTimeoutNanoseconds: 1_000_000_000
        )
        let events = await context.service.events()

        do {
            try await context.service.pair(
                uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
                source: .browser
            )
            XCTFail("Expected pairing failure")
        } catch {
            XCTAssertEqual(error, .sdk(message: "pair failed"))
        }

        let pairingStartedEvent = await nextEvent(events)
        XCTAssertEqual(pairingStartedEvent, .pairingStarted(pairingTopic: "pairing", source: .browser))

        let proposal = try makeProposalContext(pairingTopic: "pairing")
        let proposalEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.proposalReceived(proposal))
        }
        XCTAssertEqual(proposalEvent, .sessionProposal(proposal.proposal(source: .deeplink)))

        let nextEvent = await nextEvent(events, timeout: 50_000_000)
        XCTAssertNil(nextEvent)
    }

    func testPairDoesNotSubmitPairingWhenServiceStartFails() async throws {
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                configureResult: .failure(.sdk(message: "configuration failed"))
            )
        )

        do {
            try await context.service.pair(
                uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
                source: .browser
            )
            XCTFail("Expected configuration failure")
        } catch {
            XCTAssertEqual(error, .sdk(message: "configuration failed"))
        }

        let configuredCalls = await context.network.configuredCalls()
        let pairURIs = await context.network.pairURIs()
        XCTAssertEqual(configuredCalls, 1)
        XCTAssertEqual(pairURIs, [])
    }

    func testActiveSessionsStartsServiceBeforeLoadingSessions() async throws {
        let context = try await makeActiveSessionContext()

        let activeSessions = await context.service.activeSessions()

        let configuredCalls = await context.network.configuredCalls()
        XCTAssertEqual(configuredCalls, 1)
        XCTAssertEqual(activeSessions.first?.topic, "session-topic")
        XCTAssertEqual(activeSessions.first?.walletId, "wallet")
    }

    func testActiveSessionsReturnsEmptyWhenServiceStartFails() async throws {
        let session = makeSession(topic: "session-topic")
        let store = makeSessionStore()
        try store.save([
            "session-topic": WalletConnectStoredSession(
                walletId: "wallet",
                source: .browser,
                createdAt: walletConnectSessionCreatedAt
            ),
        ])
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                configureResult: .failure(.sdk(message: "configuration failed"))
            ),
            store: store
        )
        let events = await context.service.events()

        let activeSessions = await context.service.activeSessions()

        let configuredCalls = await context.network.configuredCalls()
        let errorEvent = await nextEvent(events)
        XCTAssertEqual(configuredCalls, 1)
        XCTAssertEqual(activeSessions, [])
        XCTAssertEqual(
            errorEvent,
            .error(WalletConnectErrorEvent(topic: nil, message: "sdk(message: \"configuration failed\")"))
        )
    }

    func testApproveProposalResolvesAccountsApprovesAndStoresSessionMapping() async throws {
        let session = makeSession(topic: "session-topic")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)]
            )
        )
        let proposal = try await receiveProposal(context: context)

        try await context.service.approveProposal(
            id: proposal.id,
            wallet: makeWallet()
        )

        let approveCalls = await context.network.approveProposalCalls()
        XCTAssertEqual(approveCalls.count, 1)
        XCTAssertEqual(approveCalls.first?.id, proposal.id)
        XCTAssertEqual(approveCalls.first?.namespaceKeys, ["eip155"])
        XCTAssertEqual(approveCalls.first?.accounts, ["eip155:1:0xabc"])
        XCTAssertEqual(approveCalls.first?.methods, [WalletConnectMethod.personalSign.rawValue])
        XCTAssertEqual(approveCalls.first?.events, [])
        XCTAssertEqual(
            approveCalls.first?.scopedProperties,
            ["eip155:1": #"{"atomic":{"status":"unsupported"}}"#]
        )

        let activeSessions = await context.service.activeSessions()
        XCTAssertEqual(activeSessions.first?.topic, "session-topic")
        XCTAssertEqual(activeSessions.first?.walletId, "wallet")
        XCTAssertEqual(activeSessions.first?.source, .deeplink)
    }

    func testApproveProposalInfersTONMainnetForNamespaceOnlyProposal() async throws {
        let session = makeSession(topic: "session-topic")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)]
            )
        )
        let address = "EQDmnxDMhId6v1Ofg_h5KR5coWlFG6e86Ro3pc7Tq4CA0-Jn"
        let proposal = try await receiveProposal(
            context: context,
            proposal: WalletConnectProposalContext(
                id: "proposal",
                pairingTopic: "pairing",
                dapp: makeDapp(),
                validation: .valid,
                requiredNamespaces: [
                    "ton": ProposalNamespace(
                        methods: Set(WalletConnectMethod.tonMethods.map(\.rawValue)),
                        events: []
                    ),
                ],
                optionalNamespaces: nil
            )
        )

        try await context.service.approveProposal(
            id: proposal.id,
            wallet: makeWallet(
                multichain: .multichain(.init(walletId: "wallet", addresses: [
                    MultichainWalletAddress(chain: .ton, address: address),
                ]))
            )
        )

        let approveCalls = await context.network.approveProposalCalls()
        let approveCall = try XCTUnwrap(approveCalls.first)
        XCTAssertEqual(approveCall.namespaceKeys, ["ton"])
        XCTAssertEqual(approveCall.chains, [WalletConnectChain.ton.caip2])
        XCTAssertEqual(approveCall.accounts, ["ton:-239:\(address)"])
        XCTAssertEqual(approveCall.methods, WalletConnectMethod.tonMethods.map(\.rawValue).sorted())
        XCTAssertEqual(approveCall.sessionProperties?["ton_getPublicKey"], String(repeating: "01", count: 32))
        XCTAssertFalse(approveCall.sessionProperties?["ton_getStateInit"]?.isEmpty ?? true)
        XCTAssertNil(approveCall.scopedProperties)
    }

    func testMultipleSessionsForSameWalletAreStoredAndReconciledIndependently() async throws {
        let firstSession = makeSession(topic: "session-one")
        let secondSession = makeSession(topic: "session-two")
        let store = makeSessionStore()
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [firstSession, secondSession],
                approveProposalResults: [
                    .success(firstSession),
                    .success(secondSession),
                ]
            ),
            store: store
        )

        let firstProposal = try await receiveProposal(
            context: context,
            proposal: makeProposalContext(
                id: "proposal-one",
                pairingTopic: "pairing-one"
            )
        )
        try await context.service.approveProposal(
            id: firstProposal.id,
            wallet: makeWallet()
        )
        let secondProposal = try await receiveProposal(
            context: context,
            proposal: makeProposalContext(
                id: "proposal-two",
                pairingTopic: "pairing-two"
            )
        )
        try await context.service.approveProposal(
            id: secondProposal.id,
            wallet: makeWallet()
        )

        XCTAssertEqual(store.load(), [
            "session-one": WalletConnectStoredSession(
                walletId: "wallet",
                source: .deeplink,
                createdAt: walletConnectSessionCreatedAt
            ),
            "session-two": WalletConnectStoredSession(
                walletId: "wallet",
                source: .deeplink,
                createdAt: walletConnectSessionCreatedAt
            ),
        ])

        let activeSessions = await context.service.activeSessions()
        XCTAssertEqual(activeSessions.map(\.topic).sorted(), ["session-one", "session-two"])
        XCTAssertEqual(Set(activeSessions.compactMap(\.walletId)), ["wallet"])
        XCTAssertEqual(activeSessions.first { $0.topic == "session-one" }?.source, .deeplink)
        XCTAssertEqual(activeSessions.first { $0.topic == "session-two" }?.source, .deeplink)

        let events = await context.service.events()
        let firstRequest = try makePersonalSignRequest(topic: "session-one", id: "request")
        let firstRequestEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(firstRequest, context: nil))
        }

        guard case let .sessionRequest(firstSessionRequest) = firstRequestEvent else {
            XCTFail("Expected first session request event")
            return
        }
        XCTAssertEqual(firstSessionRequest.id, "request")
        XCTAssertEqual(firstSessionRequest.topic, "session-one")
        XCTAssertEqual(firstSessionRequest.walletId, "wallet")

        let secondRequest = try makePersonalSignRequest(topic: "session-two", id: "request")
        let secondRequestEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(secondRequest, context: nil))
        }

        guard case let .sessionRequest(secondSessionRequest) = secondRequestEvent else {
            XCTFail("Expected second session request event")
            return
        }
        XCTAssertEqual(secondSessionRequest.id, "request")
        XCTAssertEqual(secondSessionRequest.topic, "session-two")
        XCTAssertEqual(secondSessionRequest.walletId, "wallet")

        try await context.service.approveRequest(
            id: "request",
            topic: "session-one",
            result: .string("0xsignature-one")
        )
        try await context.service.approveRequest(
            id: "request",
            topic: "session-two",
            result: .string("0xsignature-two")
        )

        let approveRequestCalls = await context.network.approveRequestCalls()
        XCTAssertEqual(approveRequestCalls, [
            WalletConnectApproveRequestCall(
                topic: "session-one",
                requestId: "request",
                result: .string("0xsignature-one")
            ),
            WalletConnectApproveRequestCall(
                topic: "session-two",
                requestId: "request",
                result: .string("0xsignature-two")
            ),
        ])
    }

    func testApprovingMultipleProposalsFromSamePairingStoresDistinctSessionsWithSameSource() async throws {
        let firstSession = makeSession(topic: "session-one")
        let secondSession = makeSession(topic: "session-two")
        let store = makeSessionStore()
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [firstSession, secondSession],
                approveProposalResults: [
                    .success(firstSession),
                    .success(secondSession),
                ]
            ),
            store: store
        )
        let events = await context.service.events()

        try await context.service.pair(
            uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
            source: .browser
        )
        _ = await nextEvent(events)

        let firstProposal = try await receiveProposal(
            context: context,
            events: events,
            proposal: makeProposalContext(
                id: "proposal-one",
                pairingTopic: "pairing"
            )
        )
        try await context.service.approveProposal(
            id: firstProposal.id,
            wallet: makeWallet()
        )

        let secondProposal = try await receiveProposal(
            context: context,
            events: events,
            proposal: makeProposalContext(
                id: "proposal-two",
                pairingTopic: "pairing"
            )
        )
        try await context.service.approveProposal(
            id: secondProposal.id,
            wallet: makeWallet()
        )

        XCTAssertEqual(store.load(), [
            "session-one": WalletConnectStoredSession(
                walletId: "wallet",
                source: .browser,
                createdAt: walletConnectSessionCreatedAt
            ),
            "session-two": WalletConnectStoredSession(
                walletId: "wallet",
                source: .browser,
                createdAt: walletConnectSessionCreatedAt
            ),
        ])
    }

    func testApproveProposalStorageFailureDisconnectsApprovedSDKSessionAndThrowsStorage() async throws {
        let session = makeSession(topic: "session-topic")
        let context = try await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)]
            ),
            store: makeFailingSessionStore()
        )
        let proposal = try await receiveProposal(context: context)

        do {
            try await context.service.approveProposal(
                id: proposal.id,
                wallet: makeWallet()
            )
            XCTFail("Expected storage failure")
        } catch {
            guard case .storage = error else {
                XCTFail("Expected storage error, got \(error)")
                return
            }
        }

        let disconnectTopics = await context.network.disconnectTopics()
        XCTAssertEqual(disconnectTopics, ["session-topic"])
        let rejectCalls = await context.network.rejectProposalCalls()
        XCTAssertEqual(rejectCalls, [])
    }

    func testApproveProposalEmitsSettledEventAfterMappingIsStored() async throws {
        let session = makeSession(topic: "session-topic")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)]
            )
        )
        let events = await context.service.events()
        let proposal = try await receiveProposal(context: context, events: events)

        try await context.eventStream.emit(.sessionSettled(makeRawSession(topic: "session-topic")))
        _ = await nextEvent(events)
        let activeSessionsBeforeMapping = await context.service.activeSessions()
        XCTAssertEqual(activeSessionsBeforeMapping, [])
        let disconnectTopicsBeforeMapping = await context.network.disconnectTopics()
        XCTAssertEqual(disconnectTopicsBeforeMapping, [])

        async let settledEvent = nextEvent(events)
        try await context.service.approveProposal(
            id: proposal.id,
            wallet: makeWallet()
        )

        guard case let .sessionSettled(settledSession) = await settledEvent else {
            XCTFail("Expected settled event")
            return
        }
        XCTAssertEqual(settledSession.topic, "session-topic")
        XCTAssertEqual(settledSession.walletId, "wallet")
        XCTAssertEqual(settledSession.source, .deeplink)
    }

    func testApproveProposalRejectsUnsupportedWalletKindWithUnsupportedAccountsReason() async throws {
        let context = await makeServiceContext()
        let proposal = try await receiveProposal(context: context)

        do {
            try await context.service.approveProposal(
                id: proposal.id,
                wallet: makeWallet(kind: .Signer(publicKey(), .v4R2))
            )
            XCTFail("Expected unsupported wallet kind")
        } catch {
            XCTAssertEqual(error, .unsupportedWalletKind)
        }

        let rejectCalls = await context.network.rejectProposalCalls()
        XCTAssertEqual(rejectCalls, [
            WalletConnectRejectProposalCall(
                id: proposal.id,
                reason: "unsupportedAccounts"
            ),
        ])
    }

    func testApproveProposalRejectsMissingRequiredChainWithUnsupportedChainsReason() async throws {
        let context = await makeServiceContext()
        let proposal = try await receiveProposal(
            context: context,
            proposal: makeProposalContext(requiredChains: [.tron])
        )

        do {
            try await context.service.approveProposal(
                id: proposal.id,
                wallet: makeWallet()
            )
            XCTFail("Expected unsupported required chains")
        } catch {
            XCTAssertEqual(error, .unsupportedRequiredChains([WalletConnectChain.tron.caip2]))
        }

        let rejectCalls = await context.network.rejectProposalCalls()
        XCTAssertEqual(rejectCalls, [
            WalletConnectRejectProposalCall(
                id: proposal.id,
                reason: "unsupportedChains"
            ),
        ])
    }

    func testApproveProposalIncludesSupportedRequiredSessionEvents() async throws {
        let context = await makeServiceContext()
        let proposal = try await receiveProposal(
            context: context,
            proposal: makeProposalContext(requiredEvents: ["accountsChanged", "chainChanged"])
        )

        try await context.service.approveProposal(
            id: proposal.id,
            wallet: makeWallet()
        )

        let approveCalls = await context.network.approveProposalCalls()
        XCTAssertEqual(approveCalls.count, 1)
        XCTAssertEqual(approveCalls.first?.events, ["accountsChanged", "chainChanged"])
        let rejectCalls = await context.network.rejectProposalCalls()
        XCTAssertEqual(rejectCalls, [])
    }

    func testRequestEventUsesStoredSessionMappingAndApproveSendsResponse() async throws {
        let session = makeSession(topic: "session-topic")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)]
            )
        )
        let events = await context.service.events()

        try await context.service.pair(
            uri: "wc:pairing@2?relay-protocol=irn&symKey=abc",
            source: .browser
        )
        let proposal = try await receiveProposal(
            context: context,
            events: events,
            proposal: makeProposalContext(pairingTopic: "pairing")
        )
        try await context.service.approveProposal(
            id: proposal.id,
            wallet: makeWallet()
        )
        _ = await nextEvent(events)

        let request = try makePersonalSignRequest(topic: "session-topic")
        async let requestEvent = nextEvent(events)
        try await Task.sleep(nanoseconds: 1_000_000)
        await context.eventStream.emit(.requestReceived(request, context: nil))

        guard case let .sessionRequest(sessionRequest) = await requestEvent else {
            XCTFail("Expected session request event")
            return
        }
        XCTAssertEqual(sessionRequest.id, request.id.string)
        XCTAssertEqual(sessionRequest.topic, "session-topic")
        XCTAssertEqual(sessionRequest.chain, .eth)
        XCTAssertEqual(sessionRequest.method, .personalSign)
        XCTAssertEqual(sessionRequest.walletId, "wallet")
        XCTAssertEqual(sessionRequest.source, .browser)

        try await context.service.approveRequest(
            id: request.id.string,
            topic: request.topic,
            result: .string("0xsignature")
        )

        let approveCalls = await context.network.approveRequestCalls()
        XCTAssertEqual(approveCalls, [
            WalletConnectApproveRequestCall(
                topic: "session-topic",
                requestId: request.id.string,
                result: .string("0xsignature")
            ),
        ])
    }

    func testDuplicateSessionRequestWithSameTopicAndIdIsIgnored() async throws {
        let store = makeSessionStore()
        try store.save([
            "session-topic": WalletConnectStoredSession(
                walletId: "wallet",
                source: .browser,
                createdAt: walletConnectSessionCreatedAt
            ),
        ])
        let session = makeSession(topic: "session-topic")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(activeSessionsResult: [session]),
            store: store
        )
        let events = await context.service.events()
        await context.service.start()

        let request = try makePersonalSignRequest(topic: "session-topic", id: "request")
        let requestEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        guard case let .sessionRequest(sessionRequest) = requestEvent else {
            XCTFail("Expected session request event")
            return
        }
        XCTAssertEqual(sessionRequest.id, "request")
        XCTAssertEqual(sessionRequest.topic, "session-topic")
        XCTAssertEqual(sessionRequest.walletId, "wallet")

        let duplicateEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }
        XCTAssertNil(duplicateEvent)

        try await context.service.approveRequest(
            id: request.id.string,
            topic: request.topic,
            result: .string("0xsignature")
        )
        let approveCalls = await context.network.approveRequestCalls()
        XCTAssertEqual(approveCalls.count, 1)
    }

    func testSessionRequestIdCanBeReusedAfterApprove() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        let firstRequest = try makePersonalSignRequest(topic: "session-topic", id: "request")
        let firstEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(firstRequest, context: nil))
        }
        guard case let .sessionRequest(firstSessionRequest) = firstEvent else {
            XCTFail("Expected first session request event")
            return
        }
        XCTAssertEqual(firstSessionRequest.id, "request")

        try await context.service.approveRequest(
            id: "request",
            topic: "session-topic",
            result: .string("0xsignature")
        )

        let reusedRequest = try makePersonalSignRequest(topic: "session-topic", id: "request")
        let reusedEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(reusedRequest, context: nil))
        }

        guard case let .sessionRequest(reusedSessionRequest) = reusedEvent else {
            XCTFail("Expected reused session request event")
            return
        }
        XCTAssertEqual(reusedSessionRequest.id, "request")
        XCTAssertEqual(reusedSessionRequest.topic, "session-topic")
    }

    func testSessionRequestIdCanBeReusedAfterReject() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        let firstRequest = try makePersonalSignRequest(topic: "session-topic", id: "request")
        let firstEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(firstRequest, context: nil))
        }
        guard case let .sessionRequest(firstSessionRequest) = firstEvent else {
            XCTFail("Expected first session request event")
            return
        }
        XCTAssertEqual(firstSessionRequest.id, "request")

        try await context.service.rejectRequest(
            id: "request",
            topic: "session-topic"
        )

        let reusedRequest = try makePersonalSignRequest(topic: "session-topic", id: "request")
        let reusedEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(reusedRequest, context: nil))
        }

        guard case let .sessionRequest(reusedSessionRequest) = reusedEvent else {
            XCTFail("Expected reused session request event")
            return
        }
        XCTAssertEqual(reusedSessionRequest.id, "request")
        XCTAssertEqual(reusedSessionRequest.topic, "session-topic")
    }

    func testSessionRequestIdCanBeReusedAfterExpiry() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        let firstRequest = try makePersonalSignRequest(topic: "session-topic", id: "request")
        let firstEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(firstRequest, context: nil))
        }
        guard case let .sessionRequest(firstSessionRequest) = firstEvent else {
            XCTFail("Expected first session request event")
            return
        }
        XCTAssertEqual(firstSessionRequest.id, "request")

        let expiryEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestExpired(firstRequest.id))
        }
        XCTAssertEqual(
            expiryEvent,
            .sessionRequestExpired(topic: "session-topic", requestId: "request")
        )

        let reusedRequest = try makePersonalSignRequest(topic: "session-topic", id: "request")
        let reusedEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(reusedRequest, context: nil))
        }

        guard case let .sessionRequest(reusedSessionRequest) = reusedEvent else {
            XCTFail("Expected reused session request event")
            return
        }
        XCTAssertEqual(reusedSessionRequest.id, "request")
        XCTAssertEqual(reusedSessionRequest.topic, "session-topic")
    }

    func testMalformedSigningFailureRejectsRequestWithJSONRPCInvalidParams() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        let request = try makePersonalSignRequest(topic: "session-topic", id: "request")
        let requestEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }
        guard case .sessionRequest = requestEvent else {
            XCTFail("Expected session request event")
            return
        }

        let signingError = WalletConnectSigningError.invalidTransaction(
            reason: "invalid EVM quantity value: 0xzz"
        )
        XCTAssertEqual(signingError.walletConnectRequestRejectionReason, .invalidParams)
        XCTAssertEqual(WalletConnectSigningError.canceled.walletConnectRequestRejectionReason, .userRejected)

        try await context.service.rejectRequest(
            id: "request",
            topic: "session-topic",
            reason: signingError.walletConnectRequestRejectionReason
        )

        let rejectCalls = await context.network.rejectRequestCalls()
        let rejectCall = try XCTUnwrap(rejectCalls.first)
        XCTAssertEqual(rejectCall.errorCode, -32602)
        XCTAssertEqual(rejectCall.errorMessage, "Invalid method parameter(s).")
        XCTAssertNotEqual(rejectCall.errorCode, 5000)
    }

    func testApproveRequestRetryableFailureKeepsPendingRequestForRetry() async throws {
        let session = makeSession(topic: "session-topic")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)],
                approveRequestResults: [
                    .failure(.sdk(message: "Relay request timeout", retryable: true)),
                    .success(()),
                ]
            )
        )
        let events = await context.service.events()
        let proposal = try await receiveProposal(context: context, events: events)
        try await context.service.approveProposal(id: proposal.id, wallet: makeWallet())
        _ = await nextEvent(events)

        let request = try makePersonalSignRequest(topic: "session-topic")
        _ = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        do {
            try await context.service.approveRequest(
                id: request.id.string,
                topic: request.topic,
                result: .string("0xsignature")
            )
            XCTFail("Expected retryable approve failure")
        } catch {
            XCTAssertEqual(error, .sdk(message: "Relay request timeout", retryable: true))
        }

        try await context.service.approveRequest(
            id: request.id.string,
            topic: request.topic,
            result: .string("0xsignature")
        )

        let approveRequestCalls = await context.network.approveRequestCalls()
        XCTAssertEqual(approveRequestCalls.count, 2)
    }

    func testRequestWithMissingDappIsAutoRejectedAndEmitsError() async throws {
        let context = await makeServiceContext()
        let events = await context.service.events()
        await context.service.start()

        let request = try makePersonalSignRequest(topic: "missing-topic")
        async let event = nextEvent(events)
        try await Task.sleep(nanoseconds: 1_000_000)
        await context.eventStream.emit(.requestReceived(request, context: nil))

        let errorEvent = await event
        XCTAssertEqual(
            errorEvent,
            .error(WalletConnectErrorEvent(
                topic: "missing-topic",
                message: "WalletConnect request has no dApp metadata"
            ))
        )
        await waitUntil {
            await context.network.rejectRequestCalls().count == 1
        }
    }

    func testAutoRejectStopsAfterRetryLimit() async throws {
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                rejectRequestResults: [
                    .failure(.sdk(message: "Relay request timeout", retryable: true)),
                    .failure(.sdk(message: "Relay request timeout", retryable: true)),
                    .failure(.sdk(message: "Relay request timeout", retryable: true)),
                ]
            ),
            autoRejectMaxAttempts: 2
        )
        let events = await context.service.events()
        await context.service.start()

        let request = try makePersonalSignRequest(topic: "missing-topic")
        _ = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        await waitUntil {
            await context.network.rejectRequestCalls().count == 2
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        let rejectRequestCallCount = await context.network.rejectRequestCalls().count
        XCTAssertEqual(rejectRequestCallCount, 2)
    }

    func testInvalidRequestParamsAreAutoRejectedWithJSONRPCInvalidParams() async throws {
        let session = makeSession(topic: "session-topic")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)]
            )
        )
        let events = await context.service.events()
        let proposal = try await receiveProposal(context: context, events: events)
        try await context.service.approveProposal(id: proposal.id, wallet: makeWallet())
        _ = await nextEvent(events)

        let malformedRequest = try Request(
            topic: "session-topic",
            method: WalletConnectMethod.personalSign.rawValue,
            params: Commons.AnyCodable(["0x68656c6c6f"]),
            chainId: XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))
        )
        let errorEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(malformedRequest, context: nil))
        }

        guard case .error = errorEvent else {
            XCTFail("Expected request parsing error event, got \(String(describing: errorEvent))")
            return
        }
        await waitUntil {
            await context.network.rejectRequestCalls().count == 1
        }
        let rejectCalls = await context.network.rejectRequestCalls()
        let rejectCall = try XCTUnwrap(rejectCalls.first)
        XCTAssertEqual(rejectCall.errorCode, -32602)
        XCTAssertEqual(rejectCall.errorMessage, "Invalid method parameter(s).")
    }

    func testWalletGetCapabilitiesAutoRespondsWithAtomicUnsupportedAndDoesNotEmitSigningRequest() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        let request = try makeWalletGetCapabilitiesRequest(topic: "session-topic")
        let unexpectedEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        XCTAssertNil(unexpectedEvent)
        await waitUntil {
            await context.network.approveRequestCalls().count == 1
        }
        let approveCalls = await context.network.approveRequestCalls()
        let approveCall = try XCTUnwrap(approveCalls.first)
        XCTAssertEqual(approveCall.topic, "session-topic")
        XCTAssertEqual(approveCall.requestId, "request")
        try assertUnsupportedAtomicCapabilities(
            approveCall.result,
            chainIds: ["0x1", "0x2105"]
        )
        let rejectCalls = await context.network.rejectRequestCalls()
        XCTAssertEqual(rejectCalls, [])
    }

    func testWalletGetCapabilitiesMatchesNumericallyEqualHexChainIdsAndEchoesRequestedForm() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        let request = try makeWalletGetCapabilitiesRequest(
            topic: "session-topic",
            paramsJSON: #"["0xabc",["0x01","0X2105","0xaa36a7"]]"#
        )
        let unexpectedEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        XCTAssertNil(unexpectedEvent)
        await waitUntil {
            await context.network.approveRequestCalls().count == 1
        }
        let approveCalls = await context.network.approveRequestCalls()
        let approveCall = try XCTUnwrap(approveCalls.first)
        try assertUnsupportedAtomicCapabilities(
            approveCall.result,
            chainIds: ["0x01", "0X2105"]
        )
        let rejectCalls = await context.network.rejectRequestCalls()
        XCTAssertEqual(rejectCalls, [])
    }

    func testWalletGetCapabilitiesRejectsUnauthorizedAddress() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        let request = try makeWalletGetCapabilitiesRequest(
            topic: "session-topic",
            paramsJSON: #"["0xdef",["0x1","0x2105"]]"#
        )
        let unexpectedEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        XCTAssertNil(unexpectedEvent)
        await waitUntil {
            await context.network.rejectRequestCalls().count == 1
        }
        let rejectCalls = await context.network.rejectRequestCalls()
        let rejectCall = try XCTUnwrap(rejectCalls.first)
        XCTAssertEqual(rejectCall.errorCode, 4100)
        XCTAssertEqual(rejectCall.errorMessage, "Unauthorized")
        let approveCalls = await context.network.approveRequestCalls()
        XCTAssertEqual(approveCalls, [])
    }

    func testWalletSendCallsAtomicRequiredIsAutoRejectedWithAtomicityNotSupported() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        let request = try makeRequest(
            topic: "session-topic",
            method: "wallet_sendCalls",
            paramsJSON: #"{"from":"0xabc","atomicRequired":true,"calls":[]}"#
        )
        let errorEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        guard case .error = errorEvent else {
            XCTFail("Expected unsupported method error event, got \(String(describing: errorEvent))")
            return
        }
        await waitUntil {
            await context.network.rejectRequestCalls().count == 1
        }
        let rejectCalls = await context.network.rejectRequestCalls()
        let rejectCall = try XCTUnwrap(rejectCalls.first)
        XCTAssertEqual(rejectCall.errorCode, 5760)
        XCTAssertEqual(rejectCall.errorMessage, "Atomicity not supported")
        let approveCalls = await context.network.approveRequestCalls()
        XCTAssertEqual(approveCalls, [])
    }

    func testUnknownUnsupportedMethodIsAutoRejectedWithMethodNotFound() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        let request = try makeRequest(
            topic: "session-topic",
            method: "wallet_unknown",
            paramsJSON: #"{}"#
        )
        let errorEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        guard case .error = errorEvent else {
            XCTFail("Expected unsupported method error event, got \(String(describing: errorEvent))")
            return
        }
        await waitUntil {
            await context.network.rejectRequestCalls().count == 1
        }
        let rejectCalls = await context.network.rejectRequestCalls()
        let rejectCall = try XCTUnwrap(rejectCalls.first)
        XCTAssertEqual(rejectCall.errorCode, -32601)
        XCTAssertEqual(rejectCall.errorMessage, "The method does not exist / is not available.")
        let approveCalls = await context.network.approveRequestCalls()
        XCTAssertEqual(approveCalls, [])
    }

    func testSwitchEthereumChainAutoApprovesEmitsChainChangedAndDoesNotEmitSigningRequest() async throws {
        let store = makeSessionStore()
        try store.save([
            "session-topic": WalletConnectStoredSession(
                walletId: "wallet",
                source: .browser,
                createdAt: walletConnectSessionCreatedAt
            ),
        ])
        let session = makeSession(topic: "session-topic")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                supportedSessionChains: ["session-topic": [.base]]
            ),
            store: store
        )
        let events = await context.service.events()
        await context.service.start()

        let request = try makeSwitchEthereumChainRequest(topic: "session-topic")
        let unexpectedEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        XCTAssertNil(unexpectedEvent)
        await waitUntil {
            let approveCalls = await context.network.approveRequestCalls()
            let emitCalls = await context.network.emitChainChangedCalls()
            return approveCalls.count == 1 && emitCalls.count == 1
        }

        let sessionSupportCalls = await context.network.sessionSupportCalls()
        XCTAssertEqual(
            sessionSupportCalls,
            [
                WalletConnectSessionSupportCall(
                    topic: "session-topic",
                    chain: .base,
                    method: .walletSwitchEthereumChain,
                    event: "chainChanged"
                ),
            ]
        )
        let approveRequestCalls = await context.network.approveRequestCalls()
        XCTAssertEqual(
            approveRequestCalls,
            [
                WalletConnectApproveRequestCall(
                    topic: "session-topic",
                    requestId: "request",
                    result: .null
                ),
            ]
        )
        let emitChainChangedCalls = await context.network.emitChainChangedCalls()
        XCTAssertEqual(
            emitChainChangedCalls,
            [
                WalletConnectEmitChainChangedCall(
                    topic: "session-topic",
                    chain: .base
                ),
            ]
        )
        let rejectRequestCalls = await context.network.rejectRequestCalls()
        XCTAssertEqual(rejectRequestCalls, [])
    }

    func testSwitchEthereumChainBadParamsAreRejectedWithJSONRPCInvalidParams() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        let request = try makeSwitchEthereumChainRequest(
            topic: "session-topic",
            chainId: "8453"
        )
        let errorEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        guard case .error = errorEvent else {
            XCTFail("Expected request parsing error event, got \(String(describing: errorEvent))")
            return
        }
        await waitUntil {
            await context.network.rejectRequestCalls().count == 1
        }
        let rejectCalls = await context.network.rejectRequestCalls()
        let rejectCall = try XCTUnwrap(rejectCalls.first)
        XCTAssertEqual(rejectCall.errorCode, -32602)
        XCTAssertEqual(rejectCall.errorMessage, "Invalid method parameter(s).")
        let approveRequestCalls = await context.network.approveRequestCalls()
        let emitChainChangedCalls = await context.network.emitChainChangedCalls()
        let sessionSupportCalls = await context.network.sessionSupportCalls()
        XCTAssertEqual(approveRequestCalls, [])
        XCTAssertEqual(emitChainChangedCalls, [])
        XCTAssertEqual(sessionSupportCalls, [])
    }

    func testSwitchEthereumChainUnsupportedChainIsRejectedWithJSONRPCUnsupportedChain() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        let request = try makeSwitchEthereumChainRequest(
            topic: "session-topic",
            chainId: "0x999999"
        )
        let errorEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        guard case .error = errorEvent else {
            XCTFail("Expected unsupported chain error event, got \(String(describing: errorEvent))")
            return
        }
        await waitUntil {
            await context.network.rejectRequestCalls().count == 1
        }
        let rejectCalls = await context.network.rejectRequestCalls()
        let rejectCall = try XCTUnwrap(rejectCalls.first)
        XCTAssertEqual(rejectCall.errorCode, 4902)
        XCTAssertEqual(rejectCall.errorMessage, "Unrecognized chain ID.")
        XCTAssertNotEqual(rejectCall.errorCode, 5000)
        let approveRequestCalls = await context.network.approveRequestCalls()
        let emitChainChangedCalls = await context.network.emitChainChangedCalls()
        let sessionSupportCalls = await context.network.sessionSupportCalls()
        XCTAssertEqual(approveRequestCalls, [])
        XCTAssertEqual(emitChainChangedCalls, [])
        XCTAssertEqual(sessionSupportCalls, [])
    }

    func testSwitchEthereumChainOutsideSessionNamespaceIsRejectedWithJSONRPCUnsupportedChain() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        let request = try makeSwitchEthereumChainRequest(topic: "session-topic")
        let errorEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        guard case .error = errorEvent else {
            XCTFail("Expected session namespace error event, got \(String(describing: errorEvent))")
            return
        }
        await waitUntil {
            await context.network.rejectRequestCalls().count == 1
        }
        let rejectCalls = await context.network.rejectRequestCalls()
        let rejectCall = try XCTUnwrap(rejectCalls.first)
        XCTAssertEqual(rejectCall.errorCode, 4902)
        XCTAssertEqual(rejectCall.errorMessage, "Unrecognized chain ID.")
        let approveRequestCalls = await context.network.approveRequestCalls()
        let emitChainChangedCalls = await context.network.emitChainChangedCalls()
        let sessionSupportCalls = await context.network.sessionSupportCalls()
        XCTAssertEqual(approveRequestCalls, [])
        XCTAssertEqual(emitChainChangedCalls, [])
        XCTAssertEqual(
            sessionSupportCalls,
            [
                WalletConnectSessionSupportCall(
                    topic: "session-topic",
                    chain: .base,
                    method: .walletSwitchEthereumChain,
                    event: "chainChanged"
                ),
            ]
        )
    }

    func testActiveSDKSessionWithoutMappingIsAutoDisconnectedAndHidden() async {
        let session = makeSession(topic: "orphan-topic")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(activeSessionsResult: [session])
        )

        let activeSessions = await context.service.activeSessions()

        XCTAssertEqual(activeSessions, [])
        let disconnectTopics = await context.network.disconnectTopics()
        XCTAssertEqual(disconnectTopics, ["orphan-topic"])
    }

    func testStoredMappingMissingFromSDKSessionsIsCleaned() async throws {
        let session = makeSession(topic: "session-topic")
        let store = makeSessionStore()
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)]
            ),
            store: store
        )
        let proposal = try await receiveProposal(context: context)
        try await context.service.approveProposal(id: proposal.id, wallet: makeWallet())
        XCTAssertEqual(store.load().keys.sorted(), ["session-topic"])

        await context.network.setActiveSessions([])
        let activeSessions = await context.service.activeSessions()

        XCTAssertEqual(activeSessions, [])
        XCTAssertEqual(store.load(), [:])
    }

    func testDappSideDeleteRemovesLocalMapping() async throws {
        let session = makeSession(topic: "session-topic")
        let store = makeSessionStore()
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)]
            ),
            store: store
        )
        let proposal = try await receiveProposal(context: context)
        try await context.service.approveProposal(id: proposal.id, wallet: makeWallet())
        XCTAssertEqual(store.load().keys.sorted(), ["session-topic"])

        await context.eventStream.emit(
            .sessionDeleted(
                topic: "session-topic",
                reason: WalletConnectDeleteReason()
            )
        )

        await waitUntil {
            store.load().isEmpty
        }
    }

    func testDisconnectRemovesStoredSessionMappingWhenSDKSessionIsAlreadyMissing() async throws {
        let session = makeSession(topic: "session-topic")
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)],
                disconnectResult: .failure(.missingSession(topic: "session-topic"))
            )
        )
        let proposal = try await receiveProposal(context: context)
        try await context.service.approveProposal(id: proposal.id, wallet: makeWallet())

        try await context.service.disconnect(topic: "session-topic")

        let disconnectTopics = await context.network.disconnectTopics()
        XCTAssertEqual(disconnectTopics, ["session-topic"])
        let activeSessions = await context.service.activeSessions()
        XCTAssertEqual(activeSessions, [])
    }

    func testDisconnectRemovesStoredMappingWhenSDKSessionIsAbsentAfterTerminalFailure() async throws {
        let session = makeSession(topic: "session-topic")
        let store = makeSessionStore()
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)],
                disconnectResult: .failure(.sdk(message: "disconnect failed", retryable: false))
            ),
            store: store
        )
        let proposal = try await receiveProposal(context: context)
        try await context.service.approveProposal(id: proposal.id, wallet: makeWallet())
        XCTAssertEqual(store.load().keys.sorted(), ["session-topic"])

        await context.network.setActiveSessions([])
        try await context.service.disconnect(topic: "session-topic")

        XCTAssertEqual(store.load(), [:])
        let disconnectTopics = await context.network.disconnectTopics()
        XCTAssertEqual(disconnectTopics, ["session-topic"])
    }

    func testDisconnectKeepsStoredMappingWhenTerminalFailureStillHasSDKSession() async throws {
        let session = makeSession(topic: "session-topic")
        let store = makeSessionStore()
        let context = await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                approveProposalResults: [.success(session)],
                disconnectResult: .failure(.sdk(message: "disconnect failed", retryable: false))
            ),
            store: store
        )
        let proposal = try await receiveProposal(context: context)
        try await context.service.approveProposal(id: proposal.id, wallet: makeWallet())

        do {
            try await context.service.disconnect(topic: "session-topic")
            XCTFail("Expected disconnect failure")
        } catch {
            XCTAssertEqual(error, .sdk(message: "disconnect failed", retryable: false))
        }

        XCTAssertEqual(store.load().keys.sorted(), ["session-topic"])
    }

    func testRequestAfterLocalSessionRemovalIsAutoRejectedAndDisconnected() async throws {
        let context = try await makeActiveSessionContext()
        let events = await context.service.events()
        await context.service.start()

        try await context.service.removeLocalSession(topic: "session-topic")
        let sessionDeletedEvent = await nextEvent(events)
        XCTAssertEqual(sessionDeletedEvent, .sessionDeleted(topic: "session-topic"))

        let request = try makePersonalSignRequest(topic: "session-topic", id: "request")
        let errorEvent = await nextEventAfterEmitting(events) {
            await context.eventStream.emit(.requestReceived(request, context: nil))
        }

        XCTAssertEqual(
            errorEvent,
            .error(WalletConnectErrorEvent(
                topic: "session-topic",
                message: "WalletConnect request has no wallet mapping"
            ))
        )
        await waitUntil {
            let rejectRequestCalls = await context.network.rejectRequestCalls()
            let disconnectTopics = await context.network.disconnectTopics()
            return rejectRequestCalls.count == 1 && disconnectTopics == ["session-topic"]
        }
    }
}

private extension WalletConnectServiceTests {
    struct ServiceContext {
        let service: WalletConnectServiceImplementation
        let eventStream: WalletConnectEventStream
        let network: WalletConnectWalletKitClientMock
    }

    @WalletConnectActor
    func makeServiceContext(
        network: WalletConnectWalletKitClientMock? = nil,
        store: WalletConnectSessionStore? = nil,
        pairingSourceStore: WalletConnectPairingSourceStore? = nil,
        pairingProposalTimeoutNanoseconds: UInt64 = WalletConnectPairingTimeouts.defaultProposalNanoseconds,
        autoRejectRetryDelays: [UInt64] = [1_000_000],
        autoRejectMaxAttempts: Int = 6,
        now: @escaping @Sendable () -> Date = { walletConnectSessionCreatedAt }
    ) -> ServiceContext {
        let network = network ?? WalletConnectWalletKitClientMock()
        let eventStream = WalletConnectEventStream(subscribeToWalletKit: false)
        let service = WalletConnectServiceImplementation(
            eventStream: eventStream,
            network: network,
            sessionRepository: WalletConnectSessionRepository(
                store: store ?? makeSessionStore(),
                now: now
            ),
            pairingSourceStore: pairingSourceStore ?? makePairingSourceStore(),
            autoRejectService: WalletConnectAutoRejectService(
                network: network,
                retryDelays: autoRejectRetryDelays,
                maxAttempts: autoRejectMaxAttempts
            ),
            pairingProposalTimeoutNanoseconds: pairingProposalTimeoutNanoseconds
        )
        return ServiceContext(
            service: service,
            eventStream: eventStream,
            network: network
        )
    }

    func makeActiveSessionContext(
        topic: String = "session-topic"
    ) async throws -> ServiceContext {
        let store = makeSessionStore()
        try store.save([
            topic: WalletConnectStoredSession(
                walletId: "wallet",
                source: .browser,
                createdAt: walletConnectSessionCreatedAt
            ),
        ])
        let session = makeSession(topic: topic)
        return await makeServiceContext(
            network: await WalletConnectWalletKitClientMock(
                activeSessionsResult: [session],
                walletCapabilitiesScopes: [
                    topic: WalletConnectWalletCapabilitiesScope(accounts: [
                        .init(address: "0xabc", chainId: "0x1"),
                        .init(address: "0xabc", chainId: "0x2105"),
                    ]),
                ]
            ),
            store: store
        )
    }

    func receiveProposal(
        context: ServiceContext,
        events: AsyncStream<WalletConnectServiceEvent>? = nil,
        proposal: WalletConnectProposalContext? = nil
    ) async throws -> WalletConnectSessionProposal {
        let eventStream: AsyncStream<WalletConnectServiceEvent>
        if let existingEvents = events {
            eventStream = existingEvents
        } else {
            eventStream = await context.service.events()
        }
        await context.service.start()
        let proposal = try proposal ?? makeProposalContext()
        let event = await nextEventAfterEmitting(eventStream) {
            await context.eventStream.emit(.proposalReceived(proposal))
        }
        if case let .sessionProposal(sessionProposal) = event {
            return sessionProposal
        }

        for _ in 0 ..< 3 {
            guard let event = await nextEvent(eventStream) else {
                break
            }
            if case let .sessionProposal(sessionProposal) = event {
                return sessionProposal
            }
        }
        throw XCTSkip("Expected proposal event")
    }

    func nextEventAfterEmitting(
        _ stream: AsyncStream<WalletConnectServiceEvent>,
        emit: @escaping () async -> Void
    ) async -> WalletConnectServiceEvent? {
        async let event = nextEvent(stream)
        try? await Task.sleep(nanoseconds: 1_000_000)
        await emit()
        return await event
    }

    func nextEvent(
        _ stream: AsyncStream<WalletConnectServiceEvent>,
        timeout: UInt64 = 500_000_000
    ) async -> WalletConnectServiceEvent? {
        await withTaskGroup(of: WalletConnectServiceEvent?.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeout)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await condition()), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        if !(await condition()) {
            XCTFail("Timed out waiting for condition")
        }
    }

    func makeSession(topic: String) -> WalletConnectSession {
        WalletConnectSession(
            topic: topic,
            dapp: makeDapp(),
            walletId: nil,
            sourceState: .unknown
        )
    }

    func makeDapp() -> WalletConnectDapp {
        WalletConnectDapp(
            name: "dApp",
            url: "https://example.com",
            description: "Test dApp",
            iconURL: nil
        )
    }

    func makeProposalContext(
        id: String = "proposal",
        pairingTopic: String = "pairing",
        requiredChains: [WalletConnectChain] = [.eth],
        requiredMethods: Set<String> = [WalletConnectMethod.personalSign.rawValue],
        requiredEvents: Set<String> = []
    ) throws -> WalletConnectProposalContext {
        let requiredNamespaces = try makeProposalNamespaces(
            chains: requiredChains,
            methods: requiredMethods,
            events: requiredEvents
        )
        return WalletConnectProposalContext(
            id: id,
            pairingTopic: pairingTopic,
            dapp: makeDapp(),
            validation: .valid,
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: nil
        )
    }

    func makeProposalNamespaces(
        chains: [WalletConnectChain],
        methods: Set<String>,
        events: Set<String>
    ) throws -> [String: ProposalNamespace] {
        let blockchains = try chains.map { chain in
            try XCTUnwrap(Blockchain(chain.caip2))
        }
        return [
            chains.first?.namespace ?? "eip155": ProposalNamespace(
                chains: blockchains,
                methods: methods,
                events: events
            ),
        ]
    }

    func makePersonalSignRequest(topic: String) throws -> Request {
        try Request(
            topic: topic,
            method: WalletConnectMethod.personalSign.rawValue,
            params: Commons.AnyCodable(["0x68656c6c6f", "0xabc"]),
            chainId: XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))
        )
    }

    func makePersonalSignRequest(
        topic: String,
        id: String
    ) throws -> Request {
        let expiryTimestamp = UInt64(Date().addingTimeInterval(300).timeIntervalSince1970)
        let json = """
        {
            "id": "\(id)",
            "topic": "\(topic)",
            "method": "\(WalletConnectMethod.personalSign.rawValue)",
            "params": ["0x68656c6c6f", "0xabc"],
            "chainId": "\(WalletConnectChain.eth.caip2)",
            "expiryTimestamp": \(expiryTimestamp)
        }
        """
        return try JSONDecoder().decode(Request.self, from: Data(json.utf8))
    }

    func makeSwitchEthereumChainRequest(
        topic: String,
        id: String = "request",
        chainId: String = "0x2105"
    ) throws -> Request {
        try makeRequest(
            topic: topic,
            id: id,
            method: WalletConnectMethod.walletSwitchEthereumChain.rawValue,
            paramsJSON: #"[{"chainId": "\#(chainId)"}]"#
        )
    }

    func makeWalletGetCapabilitiesRequest(
        topic: String,
        id: String = "request",
        paramsJSON: String = #"["0xabc",["0x1","0x2105","0xaa36a7"]]"#
    ) throws -> Request {
        try makeRequest(
            topic: topic,
            id: id,
            method: WalletConnectMethod.walletGetCapabilities.rawValue,
            paramsJSON: paramsJSON
        )
    }

    func makeRequest(
        topic: String,
        id: String = "request",
        method: String,
        paramsJSON: String,
        chain: WalletConnectChain = .eth
    ) throws -> Request {
        let expiryTimestamp = UInt64(Date().addingTimeInterval(300).timeIntervalSince1970)
        let json = """
        {
            "id": "\(id)",
            "topic": "\(topic)",
            "method": "\(method)",
            "params": \(paramsJSON),
            "chainId": "\(chain.caip2)",
            "expiryTimestamp": \(expiryTimestamp)
        }
        """
        return try JSONDecoder().decode(Request.self, from: Data(json.utf8))
    }

    func makeRawSession(topic: String) throws -> Session {
        try Session(
            topic: topic,
            pairingTopic: "pairing",
            peer: AppMetadata(
                name: "dApp",
                description: "Test dApp",
                url: "https://example.com",
                icons: [],
                redirect: AppMetadata.Redirect(native: "", universal: nil)
            ),
            requiredNamespaces: [:],
            namespaces: [:],
            sessionProperties: nil,
            scopedProperties: nil,
            expiryDate: Date().addingTimeInterval(60)
        )
    }

    func makeSessionStore() -> WalletConnectSessionStore {
        let vault = FileSystemVault<WalletConnectStoredSessions, String>(
            fileManager: .default,
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
        return WalletConnectSessionStore(vault: vault)
    }

    func makePairingSourceStore() -> WalletConnectPairingSourceStore {
        let vault = FileSystemVault<WalletConnectStoredPairingSources, String>(
            fileManager: .default,
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
        return WalletConnectPairingSourceStore(vault: vault)
    }

    func makeFailingSessionStore() throws -> WalletConnectSessionStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
        try Data().write(to: directory)
        let vault = FileSystemVault<WalletConnectStoredSessions, String>(
            fileManager: .default,
            directory: directory
        )
        return WalletConnectSessionStore(vault: vault)
    }

    func makeWallet(
        kind: WalletKind? = nil,
        multichain: MultichainWallet = .multichain(.init(walletId: "wallet", addresses: [
            MultichainWalletAddress(chain: .eth, address: "0xabc"),
        ]))
    ) -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: kind ?? .Regular(publicKey(), .v4R2)
            ),
            metaData: WalletMetaData(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }

    func assertUnsupportedAtomicCapabilities(
        _ result: WalletConnectResponseValue,
        chainIds: Set<String>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        guard case let .json(value) = result else {
            XCTFail("Expected JSON capabilities response", file: file, line: line)
            return
        }

        let data = try JSONEncoder().encode(value)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            file: file,
            line: line
        )
        XCTAssertEqual(Set(object.keys), chainIds, file: file, line: line)
        for chainId in chainIds {
            let capabilities = try XCTUnwrap(
                object[chainId] as? [String: Any],
                file: file,
                line: line
            )
            let atomic = try XCTUnwrap(
                capabilities["atomic"] as? [String: Any],
                file: file,
                line: line
            )
            XCTAssertEqual(atomic["status"] as? String, "unsupported", file: file, line: line)
        }
    }

    func publicKey() -> TonSwift.PublicKey {
        TonSwift.PublicKey(data: Data(repeating: 0x01, count: 32))
    }
}

private struct WalletConnectApproveProposalCall: Equatable {
    let id: String
    let namespaceKeys: [String]
    let chains: [String]
    let accounts: [String]
    let methods: [String]
    let events: [String]
    let sessionProperties: [String: String]?
    let scopedProperties: [String: String]?
}

private struct WalletConnectRejectProposalCall: Equatable {
    let id: String
    let reason: String
}

private struct WalletConnectApproveRequestCall: Equatable {
    let topic: String
    let requestId: String
    let result: WalletConnectResponseValue
}

private struct WalletConnectRejectRequestCall: Equatable {
    let topic: String
    let requestId: String
    let errorCode: Int
    let errorMessage: String
}

private struct WalletConnectSessionSupportCall: Equatable {
    let topic: String
    let chain: WalletConnectChain
    let method: WalletConnectMethod
    let event: String
}

private struct WalletConnectEmitChainChangedCall: Equatable {
    let topic: String
    let chain: WalletConnectChain
}

private struct WalletConnectDeleteReason: Reason {
    let code = 6000
    let message = "User disconnected"
}

@WalletConnectActor
private final class WalletConnectWalletKitClientMock: WalletConnectWalletKitClientProtocol, Sendable {
    private var activeSessionsResult: [WalletConnectSession]
    private var pendingProposalsResult: [WalletConnectProposalContext]
    private var pendingRequestsResult: [Request]
    private var pairResults: [Result<Void, WalletConnectPairingError>]
    private var approveProposalResults: [Result<WalletConnectSession, WalletConnectSessionApprovalError>]
    private var rejectProposalResults: [Result<Void, WalletConnectSessionRejectionError>]
    private var approveRequestResults: [Result<Void, WalletConnectResponseError>]
    private var rejectRequestResults: [Result<Void, WalletConnectResponseError>]
    private var supportedSessionChains: [String: Set<WalletConnectChain>]
    private var walletCapabilitiesScopes: [String: WalletConnectWalletCapabilitiesScope]
    private var emitChainChangedResults: [Result<Void, WalletConnectResponseError>]
    private let disconnectResult: Result<Void, WalletConnectResponseError>
    private let configureResult: Result<Void, WalletConnectConfigurationError>

    private var configuredCount = 0
    private var pairURIValues = [String]()
    private var approveProposalCallValues = [WalletConnectApproveProposalCall]()
    private var rejectProposalCallValues = [WalletConnectRejectProposalCall]()
    private var approveRequestCallValues = [WalletConnectApproveRequestCall]()
    private var rejectRequestCallValues = [WalletConnectRejectRequestCall]()
    private var sessionSupportCallValues = [WalletConnectSessionSupportCall]()
    private var emitChainChangedCallValues = [WalletConnectEmitChainChangedCall]()
    private var disconnectTopicValues = [String]()

    init(
        activeSessionsResult: [WalletConnectSession] = [],
        pendingProposalsResult: [WalletConnectProposalContext] = [],
        pendingRequestsResult: [Request] = [],
        pairResults: [Result<Void, WalletConnectPairingError>] = [],
        approveProposalResults: [Result<WalletConnectSession, WalletConnectSessionApprovalError>] = [],
        rejectProposalResults: [Result<Void, WalletConnectSessionRejectionError>] = [],
        approveRequestResults: [Result<Void, WalletConnectResponseError>] = [],
        rejectRequestResults: [Result<Void, WalletConnectResponseError>] = [],
        supportedSessionChains: [String: Set<WalletConnectChain>] = [:],
        walletCapabilitiesScopes: [String: WalletConnectWalletCapabilitiesScope] = [:],
        emitChainChangedResults: [Result<Void, WalletConnectResponseError>] = [],
        disconnectResult: Result<Void, WalletConnectResponseError> = .success(()),
        configureResult: Result<Void, WalletConnectConfigurationError> = .success(())
    ) {
        self.activeSessionsResult = activeSessionsResult
        self.pendingProposalsResult = pendingProposalsResult
        self.pendingRequestsResult = pendingRequestsResult
        self.pairResults = pairResults
        self.approveProposalResults = approveProposalResults
        self.rejectProposalResults = rejectProposalResults
        self.approveRequestResults = approveRequestResults
        self.rejectRequestResults = rejectRequestResults
        self.supportedSessionChains = supportedSessionChains
        self.walletCapabilitiesScopes = walletCapabilitiesScopes
        self.emitChainChangedResults = emitChainChangedResults
        self.disconnectResult = disconnectResult
        self.configureResult = configureResult
    }

    func configuredCalls() -> Int {
        configuredCount
    }

    func pairURIs() -> [String] {
        pairURIValues
    }

    func approveProposalCalls() -> [WalletConnectApproveProposalCall] {
        approveProposalCallValues
    }

    func rejectProposalCalls() -> [WalletConnectRejectProposalCall] {
        rejectProposalCallValues
    }

    func approveRequestCalls() -> [WalletConnectApproveRequestCall] {
        approveRequestCallValues
    }

    func rejectRequestCalls() -> [WalletConnectRejectRequestCall] {
        rejectRequestCallValues
    }

    func sessionSupportCalls() -> [WalletConnectSessionSupportCall] {
        sessionSupportCallValues
    }

    func emitChainChangedCalls() -> [WalletConnectEmitChainChangedCall] {
        emitChainChangedCallValues
    }

    func disconnectTopics() -> [String] {
        disconnectTopicValues
    }

    func setActiveSessions(_ sessions: [WalletConnectSession]) {
        activeSessionsResult = sessions
    }

    func configureIfNeeded() throws(WalletConnectConfigurationError) {
        configuredCount += 1
        try configureResult.get()
    }

    func pair(uriString: String) async throws(WalletConnectPairingError) {
        pairURIValues.append(uriString)
        guard !pairResults.isEmpty else {
            return
        }
        try pairResults.removeFirst().get()
    }

    func approveProposal(
        id: String,
        namespaces: [String: SessionNamespace],
        sessionProperties: [String: String]?,
        scopedProperties: [String: String]?
    ) async throws(WalletConnectSessionApprovalError) -> WalletConnectSession {
        approveProposalCallValues.append(
            WalletConnectApproveProposalCall(
                id: id,
                namespaceKeys: namespaces.keys.sorted(),
                chains: namespaces.values.flatMap { $0.chains ?? [] }.map(\.absoluteString).sorted(),
                accounts: namespaces.values.flatMap(\.accounts).map(\.absoluteString).sorted(),
                methods: namespaces.values.flatMap { $0.methods }.sorted(),
                events: namespaces.values.flatMap { $0.events }.sorted(),
                sessionProperties: sessionProperties,
                scopedProperties: scopedProperties
            )
        )
        guard !approveProposalResults.isEmpty else {
            return WalletConnectSession(
                topic: "approved-topic",
                dapp: WalletConnectDapp(
                    name: "dApp",
                    url: "https://example.com",
                    description: "Test dApp",
                    iconURL: nil
                ),
                walletId: nil,
                sourceState: .unknown
            )
        }
        return try approveProposalResults.removeFirst().get()
    }

    func rejectProposal(
        id: String,
        reason: RejectionReason
    ) async throws(WalletConnectSessionRejectionError) {
        rejectProposalCallValues.append(
            WalletConnectRejectProposalCall(
                id: id,
                reason: String(describing: reason)
            )
        )
        guard !rejectProposalResults.isEmpty else {
            return
        }
        try rejectProposalResults.removeFirst().get()
    }

    func approveRequest(
        topic: String,
        requestId: RPCID,
        result: WalletConnectResponseValue
    ) async throws(WalletConnectResponseError) {
        approveRequestCallValues.append(
            WalletConnectApproveRequestCall(
                topic: topic,
                requestId: requestId.string,
                result: result
            )
        )
        guard !approveRequestResults.isEmpty else {
            return
        }
        try approveRequestResults.removeFirst().get()
    }

    func rejectRequest(
        topic: String,
        requestId: RPCID,
        error: JSONRPCError
    ) async throws(WalletConnectResponseError) {
        rejectRequestCallValues.append(
            WalletConnectRejectRequestCall(
                topic: topic,
                requestId: requestId.string,
                errorCode: error.code,
                errorMessage: error.message
            )
        )
        guard !rejectRequestResults.isEmpty else {
            return
        }
        try rejectRequestResults.removeFirst().get()
    }

    func sessionSupports(
        topic: String,
        chain: WalletConnectChain,
        method: WalletConnectMethod,
        event: String
    ) -> Bool {
        sessionSupportCallValues.append(
            WalletConnectSessionSupportCall(
                topic: topic,
                chain: chain,
                method: method,
                event: event
            )
        )
        return supportedSessionChains[topic]?.contains(chain) == true
    }

    func walletCapabilitiesScope(topic: String) -> WalletConnectWalletCapabilitiesScope? {
        walletCapabilitiesScopes[topic]
    }

    func emitChainChanged(
        topic: String,
        chain: WalletConnectChain
    ) async throws(WalletConnectResponseError) {
        emitChainChangedCallValues.append(
            WalletConnectEmitChainChangedCall(
                topic: topic,
                chain: chain
            )
        )
        guard !emitChainChangedResults.isEmpty else {
            return
        }
        try emitChainChangedResults.removeFirst().get()
    }

    func disconnect(topic: String) async throws(WalletConnectResponseError) {
        disconnectTopicValues.append(topic)
        try disconnectResult.get()
    }

    func activeSessions() -> [WalletConnectSession] {
        activeSessionsResult
    }

    func pendingProposals(topic: String?) -> [WalletConnectProposalContext] {
        guard let topic else {
            return pendingProposalsResult
        }
        return pendingProposalsResult.filter { $0.pairingTopic == topic }
    }

    func pendingRequests(topic: String?) -> [Request] {
        guard let topic else {
            return pendingRequestsResult
        }
        return pendingRequestsResult.filter { $0.topic == topic }
    }
}
