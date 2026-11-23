@testable import Perps
import PerpsModels
import TKTestSupport
import XCTest

private let changed = TestSignal()

@MainActor
final class PerpsFundingFlowTests: XCTestCase {
    func testATapWhileTheTradingKeyIsKeptIsIgnoredAndTheDepositReusesTheEnteredPasscode() async {
        let deposit = FundingDepositStub(holdsTradingKey: false)
        let passcode = Gate<String?>()
        var made = 0
        let flow = PerpsFundingFlow(
            makeDeposit: {
                made += 1
                return deposit
            },
            passcodeProvider: { await passcode.wait() }
        )
        var starts: [PerpsFundingFlow.DepositStart] = []

        flow.startDeposit { starts.append($0) }
        await waitUntil { passcode.isWaiting }
        flow.startDeposit { starts.append($0) }
        XCTAssertEqual(made, 1)

        passcode.open("1234")
        await flow.depositKeyTask?.value

        XCTAssertEqual(deposit.keptWith, ["1234"])
        guard case let .ready(_, depositPasscode) = starts.first else {
            return XCTFail("expected the deposit to start")
        }
        let reused = await depositPasscode()
        XCTAssertEqual(reused, "1234")

        flow.startDeposit { starts.append($0) }
        XCTAssertEqual(made, 2)
        XCTAssertEqual(starts.count, 2)
        XCTAssertFalse(passcode.isWaiting)
    }

    func testARefusedKeyIsReportedWhileACanceledPasscodeIsNot() async {
        var deposit: FundingDepositStub?
        let passcode = Gate<String?>()
        var made = 0
        let flow = PerpsFundingFlow(
            makeDeposit: {
                made += 1
                return deposit
            },
            passcodeProvider: { await passcode.wait() }
        )
        var starts: [PerpsFundingFlow.DepositStart] = []

        flow.startDeposit { starts.append($0) }
        guard case .unavailable = starts.last else {
            return XCTFail("expected no deposit for this wallet")
        }

        deposit = FundingDepositStub(holdsTradingKey: false, keepsKey: false)
        flow.startDeposit { starts.append($0) }
        await waitUntil { passcode.isWaiting }
        passcode.open("1234")
        await flow.depositKeyTask?.value
        guard case .keyNotKept = starts.last else {
            return XCTFail("expected the refused key to be reported")
        }

        flow.startDeposit { starts.append($0) }
        await waitUntil { passcode.isWaiting }
        passcode.open(nil)
        await flow.depositKeyTask?.value
        flow.startDeposit { starts.append($0) }
        XCTAssertEqual(made, 4)
        XCTAssertEqual(starts.count, 2)

        await waitUntil { passcode.isWaiting }
        passcode.open(nil)
    }

    func testASecondAssetListTapWhileOneLoadsIsIgnoredAndAnEmptyListShowsNothing() async {
        let flow = PerpsFundingFlow(makeDeposit: { nil }, passcodeProvider: { nil })
        let list = Gate<[PerpsDepositSourceOption]>()
        var loads = 0
        let load: @MainActor () async -> [PerpsDepositSourceOption] = {
            loads += 1
            return await list.wait()
        }
        var shown: [[PerpsDepositSourceOption]] = []

        flow.loadAssets(load) { shown.append($0) }
        flow.loadAssets(load) { shown.append($0) }
        await waitUntil { list.isWaiting }
        XCTAssertEqual(loads, 1)

        list.open([])
        await flow.fundingAssetsTask?.value
        flow.loadAssets(load) { shown.append($0) }
        await waitUntil { list.isWaiting }
        XCTAssertEqual(loads, 2)
        XCTAssertTrue(shown.isEmpty)

        let option = PerpsDepositSourceOption(source: FundingDepositStub.usdc, balance: nil)
        list.open([option])
        await flow.fundingAssetsTask?.value
        XCTAssertEqual(shown, [[option]])
    }

    private func waitUntil(file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async {
        await TKTestSupport.waitUntil(changed, file: file, line: line, condition)
    }
}

@MainActor
final class FundingDepositStub: PerpsDepositing {
    static let usdc = PerpsDepositSource(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum)

    let source = FundingDepositStub.usdc
    let walletName = "Wallet"
    private(set) var holdsTradingKey: Bool
    private(set) var keptWith: [String] = []
    private let keepsKey: Bool

    init(holdsTradingKey: Bool, keepsKey: Bool = true) {
        self.holdsTradingKey = holdsTradingKey
        self.keepsKey = keepsKey
    }

    func keepTradingKey(passcode: String) async -> Bool {
        keptWith.append(passcode)
        holdsTradingKey = keepsKey
        return keepsKey
    }

    func loadBalance() async -> PerpsFundingBalance? {
        nil
    }

    func review(amount _: String) async throws -> PerpsReviewedDeposit {
        throw CancellationError()
    }

    func message(for _: Error) -> PerpsDepositMessage {
        .failed
    }
}

@MainActor
private final class Gate<Value: Sendable> {
    private var pending: CheckedContinuation<Value, Never>?

    var isWaiting: Bool {
        pending != nil
    }

    func wait() async -> Value {
        await withCheckedContinuation {
            pending = $0
            changed.send()
        }
    }

    func open(_ value: Value) {
        pending?.resume(returning: value)
        pending = nil
    }
}
