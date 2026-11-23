@preconcurrency import BigInt
import ChainKit
@testable import KeeperCore
import OperationReviewModels
import TKLogging
import XCTest

final class OperationGateTests: XCTestCase {
    func test_withoutChecks_nothingIsBuiltAndEverythingPasses() async throws {
        let gate = OperationGate { [] }
        var builds = 0
        let build = { () async throws -> [SignableOperation] in
            builds += 1
            throw StubFailure()
        }

        let askedPreview = await gate.preview(.ask, build)
        let loggedPreview = await gate.preview(.logOnly, build)
        try await gate.clear(.ask, consent: .refuse, build)
        try await gate.clear(.logOnly, consent: .refuse, build)

        XCTAssertNil(askedPreview)
        XCTAssertNil(loggedPreview)
        XCTAssertEqual(builds, 0)
    }

    func test_anInfoOnlyReviewNeverAsks() async throws {
        let user = AskedUser(answer: false)
        let gate = OperationGate { [StubCheck(found: [.info])] }

        let preview = await gate.preview(.ask) { try [signable()] }
        try await gate.clear(.ask, consent: OperationConsent { await user.ask($0) }) { try [signable()] }

        XCTAssertEqual(preview?.severity, .info)
        XCTAssertEqual(preview?.requiresConsent, false)
        let asked = await user.asked
        XCTAssertEqual(asked, [])
    }

    func test_aWarningOrADangerIsAskedOnceAndPassesWhenAccepted() async throws {
        for severity in [OperationFinding.Severity.warning, .danger] {
            let user = AskedUser(answer: true)
            let gate = OperationGate { [StubCheck(found: [.info, severity])] }

            let preview = await gate.preview(.ask) { try [signable()] }
            try await gate.clear(.ask, consent: OperationConsent { await user.ask($0) }) { try [signable()] }

            let review = try XCTUnwrap(preview)
            XCTAssertEqual(review.severity, severity)
            let asked = await user.asked
            XCTAssertEqual(asked, [review.id], "\(severity)")
        }
    }

    func test_aRefusalIsDeclined() async {
        let user = AskedUser(answer: false)
        let gate = OperationGate { [StubCheck(found: [.danger])] }

        await assertRefusal(.declined) {
            try await gate.clear(.ask, consent: OperationConsent { await user.ask($0) }) { try [signable()] }
        }
        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
    }

    func test_whatCannotBeBuiltOrCheckedIsUnreviewableWhenAskedAndPassesWhenOnlyLogged() async throws {
        let failures: [(gate: OperationGate, build: () async throws -> [SignableOperation])] = [
            (OperationGate { [StubCheck(found: [.danger])] }, { throw StubFailure() }),
            (OperationGate { [StubCheck(found: [.danger]), StubCheck(fails: true)] }, { try [signable()] }),
        ]
        let log = RecordedLog()
        defer { log.stop() }

        for (gate, build) in failures {
            let preview = await gate.preview(.ask, build)
            await assertRefusal(.unreviewable(reason: StubFailure().logDescription)) {
                try await gate.clear(.ask, consent: OperationConsent { _ in true }, build)
            }
            try await gate.clear(.logOnly, consent: .refuse, build)

            XCTAssertNil(preview)
        }
        _ = try await log.records("Operation review could not check what is signed", count: 3)

        XCTAssertEqual(
            log.errors.map(\.message),
            Array(repeating: "Operation review could not build what is signed", count: 3)
                + Array(repeating: "Operation review could not check what is signed", count: 3)
        )
        XCTAssertEqual(log.errors.first?.extraInfo["check"], nil)
        XCTAssertEqual(log.errors.last?.extraInfo["operations"], "op-1")
        XCTAssertEqual(log.errors.last?.extraInfo["fidelity"], "exact")
        XCTAssertEqual(log.errors.last?.extraInfo["check"], "StubCheck")
        XCTAssertEqual(Set(log.errors.map(\.file)), ["KeeperCoreTests/OperationGateTests.swift"], "logged as the gate's caller")
    }

    func test_findingsOfAFlowThatIsOnlyLoggedAreNeitherAskedNorShown() async throws {
        let user = AskedUser(answer: false)
        let gate = OperationGate { [StubCheck(found: [.info, .warning, .danger])] }
        let log = RecordedLog()
        defer { log.stop() }

        let preview = await gate.preview(.logOnly) { try [signable()] }
        _ = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)
        try await gate.clear(.logOnly, consent: OperationConsent { await user.ask($0) }) {
            try [signable(fidelity: .converted)]
        }
        _ = try await log.records("Operation review found what would ask in a flow it only logs", count: 2)

        XCTAssertNil(preview)
        let asked = await user.asked
        XCTAssertEqual(asked, [])
        XCTAssertEqual(log.errors.map(\.extraInfo), [
            ["operations": "op-1", "assets": "eth/mainnet/coin", "fidelity": "exact", "findings": "warning:Stubwarning,danger:Stubdanger"],
            ["operations": "op-1", "assets": "eth/mainnet/coin", "fidelity": "converted", "findings": "warning:Stubwarning,danger:Stubdanger"],
        ])
        XCTAssertEqual(Set(log.errors.map(\.file)), ["KeeperCoreTests/OperationGateTests.swift"], "logged as the gate's caller")
    }

    /// chain-kit may read the network to check what is signed, and nothing cancels that: a flow only
    /// logged goes on while its checks read, and what they find is logged as the flow's once they are
    /// done.
    func test_aFlowThatIsOnlyLoggedIsNotKeptWaitingForItsChecks() async throws {
        let reviews: [(name: String, review: (OperationGate) async throws -> Void)] = [
            ("preview", { _ = await $0.preview(.logOnly) { try [signable()] } }),
            ("clear", { try await $0.clear(.logOnly, consent: .refuse) { try [signable()] } }),
        ]
        for (name, review) in reviews {
            let log = RecordedLog()
            defer { log.stop() }
            let flow = FlowEvents()

            try await review(OperationGate { [HeldCheck(flow: flow)] })
            await flow.append(.wentOn)
            let logged = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)

            let events = await flow.all
            XCTAssertEqual(events, [.wentOn, .read], name)
            XCTAssertEqual(logged.map(\.severity), [.error], name)
            XCTAssertEqual(logged.map(\.file), ["KeeperCoreTests/OperationGateTests.swift"], "\(name) is logged as the gate's caller")
        }
    }

    func test_everyOperationOfAReviewIsChecked() async throws {
        let user = AskedUser(answer: false)
        let gate = OperationGate { [StubCheck(found: [.danger], operation: "op-2")] }
        let build = { try [signable(id: "op-1"), signable(id: "op-2")] }
        let log = RecordedLog()
        defer { log.stop() }

        let preview = await gate.preview(.ask, build)
        await assertRefusal(.declined) {
            try await gate.clear(.ask, consent: OperationConsent { await user.ask($0) }, build)
        }
        try await gate.clear(.logOnly, consent: .refuse, build)
        _ = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)

        XCTAssertEqual(preview?.severity, .danger)
        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
        XCTAssertEqual(log.errors.map(\.extraInfo), [
            ["operations": "op-1,op-2", "assets": "eth/mainnet/coin,eth/mainnet/coin", "fidelity": "exact,exact", "findings": "danger:Stubdanger"],
        ])
    }

    func test_aCancelledTaskIsDeclinedWithoutAsking() async throws {
        let user = AskedUser(answer: true)
        let gate = OperationGate { [StubCheck(found: [.warning])] }

        for buildFails in [false, true] {
            let log = RecordedLog()
            defer { log.stop() }
            let clearing = Task {
                try await gate.clear(.ask, consent: OperationConsent { await user.ask($0) }) {
                    while !Task.isCancelled {
                        await Task.yield()
                    }
                    if buildFails {
                        throw CancellationError()
                    }
                    return try [signable()]
                }
            }
            clearing.cancel()

            let result = await clearing.result

            XCTAssertThrowsError(try result.get(), "\(buildFails)") { XCTAssertEqual($0 as? OperationRefusal, .declined) }
            XCTAssertEqual(log.errors.count, 0, "\(buildFails)")
        }
        let asked = await user.asked
        XCTAssertEqual(asked, [])
    }

    func test_aTaskCancelledWhileTheUserAnswersIsDeclined() async {
        let gate = OperationGate { [StubCheck(found: [.warning])] }
        let clearing = Task {
            try await gate.clear(.ask, consent: OperationConsent { _ in
                _ = withUnsafeCurrentTask { $0?.cancel() }
                return true
            }) { try [signable()] }
        }

        let result = await clearing.result

        XCTAssertThrowsError(try result.get()) { XCTAssertEqual($0 as? OperationRefusal, .declined) }
    }

    func test_theReviewIdIsTheSameForTheSameContent() async throws {
        let first = try await reviewId(of: [signable()])
        let second = try await reviewId(of: [signable()])

        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }

    /// A symbol only names the asset in a finding: what is signed and agreed to stays the same.
    func test_theReviewIdLeavesOutTheSymbolASpendIsNamedBy() async throws {
        let renamed = OperationIntent.Spend(assetId: "eth/mainnet/coin", symbol: "WETH", decimals: 18, amount: 1000)

        let named = try await reviewId(of: [signable()])
        let other = try await reviewId(of: [signable(intent: .wallet(spending: [renamed], to: Fixture.recipient))])

        XCTAssertNotNil(named)
        XCTAssertEqual(named, other)
    }

    func test_theReviewIdChangesWithWhatIsSignedAndAgreedTo() async throws {
        let usdt = try XCTUnwrap(AssetCompanion.shared.fromString(assetId: Fixture.usdtId, name: "Tether USD", symbol: "USDT", decimals: 6))
        let changes: [String: [SignableOperation]] = try [
            "operation id": [signable(id: "op-2")],
            "operation meta": [signable(value: "2000")],
            "sender address": [signable(sender: Fixture.otherSender)],
            "account asset": [signable(asset: usdt)],
            "account key": [signable(key: nil)],
            "spent asset": [signable(intent: .wallet(spending: [Fixture.spend(assetId: Fixture.usdtId)], to: Fixture.recipient))],
            "spent amount": [signable(intent: .wallet(spending: [Fixture.spend(amount: 1001)], to: Fixture.recipient))],
            "spent decimals": [signable(intent: .wallet(spending: [Fixture.spend(decimals: 9)], to: Fixture.recipient))],
            "no spends": [signable(intent: .wallet(spending: [], to: Fixture.recipient))],
            "relayer fee": [signable(intent: .wallet(spending: [Fixture.spend()], relayerFee: Fixture.spend(amount: 5), to: Fixture.recipient))],
            "recipient": [signable(intent: .wallet(spending: [Fixture.spend()], to: Fixture.sender))],
            "source": [signable(intent: .dapp)],
            "another operation": [signable(), signable(id: "op-2")],
        ]

        let baseId = try await reviewId(of: [signable()])
        let base = try XCTUnwrap(baseId)
        for (change, variant) in changes {
            let id = await reviewId(of: variant)
            XCTAssertNotNil(id, change)
            XCTAssertNotEqual(id, base, change)
        }
        let pair = try await reviewId(of: [signable(), signable(id: "op-2")])
        let pairWithAnotherSecond = try await reviewId(of: [signable(), signable(id: "op-2", value: "2000")])
        XCTAssertNotEqual(pair, pairWithAnotherSecond, "the second operation's meta")
        let feeApart = try await reviewId(of: [signable(intent: .wallet(spending: [Fixture.spend()], relayerFee: Fixture.spend(amount: 5), to: Fixture.recipient))])
        let feeAsSpend = try await reviewId(of: [signable(intent: .wallet(spending: [Fixture.spend(), Fixture.spend(amount: 5)], to: Fixture.recipient))])
        XCTAssertNotEqual(feeApart, feeAsSpend, "a relayer's fee is no spend: chain-kit may hold it on its own")
    }
}

private extension OperationGateTests {
    func reviewId(of signables: [SignableOperation]) async -> String? {
        await OperationGate { [StubCheck()] }.preview(.ask) { signables }?.id
    }

    func assertRefusal(
        _ expected: OperationRefusal,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ clear: () async throws -> Void
    ) async {
        do {
            try await clear()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? OperationRefusal, expected, file: file, line: line)
        }
    }
}

private enum Fixture {
    static let sender = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
    static let otherSender = "0x24b576bc271823bf9c24be627b4363b9b00191e9"
    static let recipient = "0x3b4d794a66304f130a4db8f2551b0070dfcf5ca7"
    static let key = MultichainPublicKey(defaultHex: "0x0237b0bb7a8288d38ed49a524b5dc98cff3eb5ca824c9f9dc0dfdb3d9cd600f299", segWit: "")
    static let usdtId = "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"

    static func spend(assetId: String = "eth/mainnet/coin", amount: BigUInt = 1000, decimals: Int = 18) -> OperationIntent.Spend {
        OperationIntent.Spend(assetId: assetId, symbol: "ETH", decimals: decimals, amount: amount)
    }
}

private func signable(
    id: String = "op-1",
    value: String = "1000",
    sender: String = Fixture.sender,
    asset: Asset? = nil,
    key: MultichainPublicKey? = Fixture.key,
    intent: OperationIntent = .wallet(spending: [Fixture.spend()], to: Fixture.recipient),
    fidelity: SignableOperation.Fidelity = .exact
) throws -> SignableOperation {
    try SignableOperation(
        operation: ChainKitOperationSender.parse(
            id: id,
            payloads: #"[{"chain_id":"eth/mainnet","id":"p_01","type":"main","version":1,"meta":{"to":"\#(Fixture.recipient)","value":"\#(value)"}}]"#
        ),
        account: ChainKitOperationSender.account(
            of: MultichainWalletAddress(chain: .eth, address: sender, publicKey: key),
            asset: asset
        ),
        intent: intent,
        fidelity: fidelity
    )
}

private struct StubFailure: Error {}

private struct StubCheck: OperationCheck {
    var found: [OperationFinding.Severity] = []
    /// When set, the only operation the findings are in.
    var operation: String?
    var fails = false

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        if fails {
            throw StubFailure()
        }
        guard operation.map({ $0 == signable.operation.id }) ?? true else {
            return []
        }
        return found.enumerated().map { index, severity in
            OperationFinding(id: "\(signable.operation.id):\(index)", kind: "Stub\(severity)", severity: severity, title: "Finding")
        }
    }
}

/// When the flow went on and when a check read, in the order they came.
private actor FlowEvents {
    enum Event: Equatable {
        case wentOn
        case read
    }

    private(set) var all = [Event]()

    func append(_ event: Event) {
        all.append(event)
    }

    /// Waits up to five seconds for the flow to go on.
    func waitForTheFlow() async throws {
        for _ in 0 ..< 500 where !all.contains(.wentOn) {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

/// Reads only once the flow went on, or after five seconds, as a lookup on the network would
/// outlast the flow, and finds a warning in what it reads.
private struct HeldCheck: OperationCheck {
    let flow: FlowEvents

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        try await flow.waitForTheFlow()
        await flow.append(.read)
        return [OperationFinding(id: signable.operation.id, kind: "StubWarning", severity: .warning, title: "Finding")]
    }
}

private actor AskedUser {
    private let answer: Bool
    private(set) var asked = [String]()

    init(answer: Bool) {
        self.answer = answer
    }

    func ask(_ review: OperationReview) -> Bool {
        asked.append(review.id)
        return answer
    }
}

/// Collects what is logged until stopped, from whichever task logs it: the checks of a review only
/// logged run in a task of their own, which a test waits for before it ends.
final class RecordedLog: LogBackend {
    private let configuration = Log.configuration
    private let lock = NSLock()
    private var logged = [LogRecord]()

    var records: [LogRecord] {
        lock.withLock { logged }
    }

    var errors: [LogRecord] {
        records.filter { $0.severity == .error }
    }

    init() {
        Log.configuration = LoggingConfiguration(minimumSeverity: .debug, defaultSubsystem: "test", backends: [self])
    }

    func log(_ record: LogRecord) {
        lock.withLock { logged.append(record) }
    }

    /// The first record of `message`, waited for up to five seconds.
    func record(_ message: String) async throws -> LogRecord? {
        try await records(message, count: 1).first
    }

    /// The records of `message` once there are `count` of them, waited for up to five seconds.
    func records(_ message: String, count: Int) async throws -> [LogRecord] {
        for _ in 0 ..< 500 where records.filter({ $0.message == message }).count < count {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return records.filter { $0.message == message }
    }

    func stop() {
        Log.configuration = configuration
    }
}
