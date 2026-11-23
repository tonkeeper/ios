import BigInt
import ChainKit
import Foundation
@testable import KeeperCore
import OperationReviewModels
import TKFeatureFlags
import TonSwift
import TronSwift
import TronSwiftAPI
import XCTest

/// Where a TRON send clears what it signs: the transaction the node built, once extended, ahead of the
/// passcode and the device, and the GRAM it pays an instant fee with, ahead of the App's signature. The
/// node is stubbed over HTTP; the send is 10 TRX or 10 USDT relayed by the battery.
final class TronUSDTSendGateTests: XCTestCase {
    private static let sender = "TVdW9qX4kyXb9jFoUwXJswtEqKHdn85AVd"
    private static let recipient = "TU1r33n75FL5dShBt13xcJfgBLuahLgTZo"
    private static let amount: BigUInt = 10_000_000
    private static let usdtId = "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
    /// The key a multichain wallet stored for its TRON address.
    private static let storedKey = MultichainPublicKey(defaultHex: "0x02" + String(repeating: "07", count: 32), segWit: "")
    private static let instantFee: BigUInt = 100_000_000
    private static let foreign = "TCaxmZvD5kysgFNSqovSpxKKkZdD818cvr"

    private let calls = TronSwapCalls()
    /// When the node built the transaction: a minute before the expiration it gave it.
    private let clock = PaymentClock(Date(timeIntervalSince1970: TimeInterval(TronNodeStub.expiration - 60000) / 1000))
    private var checks = [any OperationCheck]()
    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    override func setUpWithError() throws {
        try super.setUpWithError()
        TronNodeStub.calls = calls
        TronNodeStub.owner = try TronSwift.Address(address: Self.sender).raw
        TronNodeStub.deposit = try TronSwift.Address(address: Self.recipient).raw
    }

    override func tearDown() {
        TronNodeStub.calls = nil
        super.tearDown()
    }

    func test_withoutChecksTheTransferIsSignedAndSentAsBefore() async throws {
        let controller = try await makeController(wallet: multichainWallet(), sender: Self.sender)

        let result = await controller.sendTransaction(consent: .refuse)

        guard case .success = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        XCTAssertEqual(calls.recorded.filter { $0 == "sign" }.count, 1)
        XCTAssertEqual(calls.relayed.count, 1)
    }

    func test_aTransferIsAskedAboutOnceBuiltAndARefusalSignsNothing() async throws {
        checks = [WarningCheck()]
        let controller = try await makeController(wallet: multichainWallet(), sender: Self.sender)
        let user = ConsentingUser(answering: false) { [calls] in calls.record("ask") }

        let result = await controller.sendTransaction(consent: user.attempt())

        guard case .failure(.cancelledByUser) = result else {
            return XCTFail("expected a cancellation, got \(result)")
        }
        XCTAssertEqual(calls.recorded, ["/wallet/createtransaction", "ask"])
        XCTAssertTrue(calls.relayed.isEmpty)
    }

    func test_theTransactionTheUserAcceptsIsTheOneSigned() async throws {
        checks = [WarningCheck()]
        let controller = try await makeController(wallet: multichainWallet(), sender: Self.sender)
        let user = ConsentingUser(answering: true) { [calls] in calls.record("ask") }

        let result = await controller.sendTransaction(consent: user.attempt())

        guard case .success = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        XCTAssertEqual(calls.recorded, ["/wallet/createtransaction", "ask", "sign"])
        let relayed = try XCTUnwrap(calls.relayed.first)
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(Data(base64Encoded: relayed))) as? [String: Any])
        let asked = await user.asked
        XCTAssertEqual(asked.first?.findings.map(\.id), try [XCTUnwrap(sent["txID"] as? String)])
    }

    /// Expiry during review returns to a fresh quote without signing or retrying a relay.
    func test_aTransactionThatExpiredWhileTheUserReadIsNotSigned() async throws {
        checks = [WarningCheck()]
        let controller = try await makeController(wallet: multichainWallet(), sender: Self.sender)
        let user = ConsentingUser(answering: true) { [calls, clock] in
            calls.record("ask")
            clock.advance(by: 20 * 60)
        }

        let result = await controller.sendTransaction(consent: user.attempt())

        guard case .failure(.multichainTransactionFailure(.operationExpired)) = result else {
            return XCTFail("expected a fresh quote, got \(result)")
        }
        XCTAssertEqual(calls.recorded, ["/wallet/createtransaction", "ask"])
        XCTAssertTrue(calls.relayed.isEmpty)
    }

    /// A legacy wallet has no multichain state: the send is read from the TRON address it signs with.
    func test_aLegacyWalletIsReviewedFromItsOwnTronAddress() async throws {
        let wallet = legacyWallet()
        let tron = try XCTUnwrap(wallet.tron).address
        TronNodeStub.owner = tron.raw
        let check = WarningCheck()
        checks = [check]
        let controller = try await makeController(wallet: wallet, sender: nil)

        _ = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

        let reads = await check.reads.all
        XCTAssertEqual(reads, [WarningCheck.Read(
            address: tron.base58.lowercased(),
            assetId: "tron/mainnet/coin",
            intent: .wallet(spending: [OperationIntent.Spend(assetId: "tron/mainnet/coin", symbol: "TRX", decimals: 6, amount: Self.amount)], to: Self.recipient)
        )])
        XCTAssertEqual(calls.relayed.count, 1)
    }

    /// The USDT a multichain wallet sends on TRON: the contract's transfer the node built is read as the
    /// token, from the address that signs it, with the key that address stored.
    func test_aUSDTTransferIsReviewedAsTheTokenFromTheKeyItsAddressStored() async throws {
        let check = AccountCheck(calls: calls)
        checks = [check]
        let controller = try await makeController(wallet: multichainWallet(), sender: Self.sender, token: .usdt)

        let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

        guard case .success = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        let reads = await check.reads.all
        XCTAssertEqual(reads, [AccountCheck.Read(
            address: Self.sender,
            assetId: Self.usdtId,
            publicKey: Self.storedKey.defaultHex,
            intent: .wallet(spending: [OperationIntent.Spend(assetId: Self.usdtId, symbol: "USD₮", decimals: 6, amount: Self.amount)], to: Self.recipient)
        )])
        XCTAssertEqual(calls.recorded, ["/wallet/triggersmartcontract", "review \(Self.usdtId)", "sign"])
        XCTAssertEqual(calls.relayed.count, 1)
    }

    /// The GRAM an instant fee is paid with is a TON transfer the wallet signs besides: it is read from
    /// the wallet's own TON account and held to the fee confirmed, beside the App's signature, which
    /// does not wait for it, and a finding in it never stops the send.
    func test_theInstantFeeIsReviewedAsTheGramItPays() async throws {
        let check = AccountCheck(calls: calls)
        checks = [check]
        let log = RecordedLog()
        defer { log.stop() }
        let wallet = multichainWallet(holdingTon: true)
        let controller = try await makeController(
            wallet: wallet,
            sender: Self.sender,
            token: .usdt,
            sendService: SendServiceStub(seqno: 7),
            balanceService: BalanceServiceStub(tonBalance: 1_000_000_000)
        )
        controller.signHandler = { [calls] _, _ in
            calls.record("sign fee")
            return ["fee boc"]
        }
        guard case .success = await controller.emulate() else {
            return XCTFail("expected the transfer to be priced")
        }
        controller.setPrefferedExtraType(extraType: .default)

        let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())
        let logged = try await log.record("Operation review found what would ask in a flow it only logs")

        guard case .success = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        let steps = calls.recorded.filter { !$0.hasPrefix("/") }
        XCTAssertEqual(Array(steps.prefix(2)), ["review \(Self.usdtId)", "sign"])
        XCTAssertEqual(Set(steps.dropFirst(2)), ["review ton/mainnet/coin", "sign fee"])
        XCTAssertNotNil(logged)
        let ton = try ChainKitOperationSender.tonAccount(of: wallet)
        let reads = await check.reads.all
        XCTAssertEqual(reads.last, AccountCheck.Read(
            address: ton.addressDisplay,
            assetId: "ton/mainnet/coin",
            publicKey: ton.publicKey?.defaultHex,
            intent: .wallet(spending: [OperationIntent.Spend(assetId: "ton/mainnet/coin", symbol: "GRAM", decimals: 9, amount: Self.instantFee)], to: nil)
        ))
        XCTAssertEqual(calls.relayedInstantFees, ["fee boc"])
    }

    /// The app's own verification refuses a transfer the node builds to another address before the
    /// gate, so chain-kit's verdict on one is stubbed. Read as the check reads it, it is a danger: the
    /// send is asked about once it is built, and nothing is signed before the answer.
    func test_aTransactionChainKitFlagsIsAskedAboutBeforeItIsSigned() async throws {
        checks = [ForeignRecipientVerdict(recipient: Self.recipient, actual: Self.foreign)]
        let controller = try await makeController(wallet: multichainWallet(), sender: Self.sender, token: .usdt)
        let user = ConsentingUser(answering: false) { [calls] in calls.record("ask") }

        let result = await controller.sendTransaction(consent: user.attempt())

        guard case .failure(.cancelledByUser) = result else {
            return XCTFail("expected a cancellation, got \(result)")
        }
        XCTAssertEqual(calls.recorded, ["/wallet/triggersmartcontract", "ask"])
        let asked = await user.asked
        XCTAssertEqual(asked.map(\.severity), [.danger])
        XCTAssertTrue(calls.relayed.isEmpty)
    }

    /// What the node builds to pay the recipient what was confirmed is read by chain-kit, which finds
    /// nothing in it, not even what it could not read: TRX or USDT, from a multichain wallet or from a
    /// legacy one's own TRON address.
    func test_aTransactionChainKitFindsNothingInIsSignedWithoutAsking() async throws {
        let check = FindingsCheck(reading: ChainKitValidationCheck(client: client))
        checks = [check]
        let log = RecordedLog()
        defer { log.stop() }
        let legacy = legacyWallet()
        let sends: [(wallet: Wallet, sender: String?, token: TronToken)] = [
            (multichainWallet(), Self.sender, .trx),
            (multichainWallet(), Self.sender, .usdt),
            (legacy, nil, .usdt),
        ]

        for send in sends {
            TronNodeStub.owner = try (send.sender.map { try TronSwift.Address(address: $0) } ?? XCTUnwrap(send.wallet.tron).address).raw
            let controller = try await makeController(wallet: send.wallet, sender: send.sender, token: send.token)
            let user = ConsentingUser(answering: false)

            let result = await controller.sendTransaction(consent: user.attempt())

            guard case .success = result else {
                XCTFail("expected the \(send.token) transfer of \(send.wallet.id) to go out, got \(result)")
                continue
            }
            let asked = await user.asked
            XCTAssertEqual(asked, [], "\(send.token) of \(send.wallet.id)")
        }
        XCTAssertEqual(calls.relayed.count, sends.count)
        let found = await check.found.all
        XCTAssertEqual(found, Array(repeating: [], count: sends.count))
        XCTAssertEqual(log.errors.map(\.message), [])
    }

    func test_aTransferNoCheckCouldReadFailsTheSendAndIsNoCancellation() async throws {
        checks = [FailingCheck()]
        let controller = try await makeController(wallet: multichainWallet(), sender: Self.sender)

        let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

        guard case .failure(.failedToSendTransaction) = result else {
            return XCTFail("expected a failed send, got \(result)")
        }
        XCTAssertFalse(calls.recorded.contains("sign"))
        XCTAssertTrue(calls.relayed.isEmpty)
    }
}

private extension TronUSDTSendGateTests {
    func makeController(
        wallet: Wallet,
        sender: String?,
        token: TronToken = .trx,
        sendService: SendServiceStub = SendServiceStub(),
        balanceService: BalanceServiceStub = BalanceServiceStub()
    ) async throws -> TronUSDTTransactionConfirmationController {
        let session = TronNodeStub.session()
        // A configuration that never answered keeps TRON in the TRX-only region, where nothing is relayed.
        let mainnet = try JSONDecoder().decode(BootConfiguration.self, from: Data(#"{"flags": {"trx_only_region": false}}"#.utf8))
        let configuration = KeeperCore.Configuration(
            bootConfigurationService: BootConfigurationServiceStub(bootConfigurations: BootConfigurations(mainnet: mainnet, testnet: .empty)),
            featureFlags: DummyFeatureFlags(),
            tkAppSettings: AppSettingsStub()
        )
        let batteryService = BatteryServiceStub(
            calls: calls,
            estimate: .init(
                energy_charges: 0,
                bandwidth_charges: 5,
                activation_charges: 0,
                total_charges: 5,
                instant_fee: .init(
                    fee_address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c",
                    accepted_assets: [.init(_type: .ton, name: "GRAM", amount_nano: Self.instantFee.description, decimals: 9)]
                )
            )
        )
        let chainParameters = TronChainParametersRepositoryImplementation()
        await chainParameters.setChainFees(
            TronChainFees(energySun: 100, bandwidthSun: 1000, createAccountSun: 100_000, createNewAccountSun: 1_000_000, createNewAccountBandwidthRate: 1)
        )
        let controller = try TronUSDTTransactionConfirmationController(
            wallet: wallet,
            token: token,
            recipient: TronSwift.Address(address: Self.recipient),
            amount: Self.amount,
            balance: 100_000_000,
            senderAddress: sender.map { try TronSwift.Address(address: $0) },
            tronUsdtApi: TronUSDTAPI(
                tronApi: TronApi(urlSession: session, baseApiUrl: XCTUnwrap(URL(string: "https://tron.test")), pause: { _ in }),
                batteryAPI: BatteryAPI(hostProvider: BatteryHostStub(), urlSession: session),
                batteryService: batteryService,
                chainParametersRepository: chainParameters
            ),
            sendService: sendService,
            balanceService: balanceService,
            configuration: configuration,
            gate: OperationGate { [checks] in checks },
            now: { [clock] in clock.now }
        )
        controller.tronSignHandler = { [calls] _, _ in
            calls.record("sign")
            return Data(repeating: 1, count: 65)
        }
        return controller
    }

    /// The wallet's TRON address, with the key it stored, and its own TON address when `holdingTon`.
    func multichainWallet(holdingTon: Bool = false) -> Wallet {
        let tron = MultichainWalletAddress(chain: .tron, address: Self.sender, publicKey: Self.storedKey)
        let ton = MultichainWalletAddress(
            chain: .ton,
            address: "UQBcmqkZxhc81WNeFFzq9ZX6qBlP28B-MuYeSxpS_-YMIDNl",
            type: .tonV4R2,
            publicKey: MultichainPublicKey(defaultHex: "0x" + String(repeating: "07", count: 32), segWit: "")
        )
        return Wallet(
            id: "wallet-id",
            identity: .init(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: .init(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init(),
            multichain: .multichain(MultichainWalletState(
                walletId: "multichain-wallet-id",
                addresses: holdingTon ? [tron, ton] : [tron]
            ))
        )
    }
}

/// chain-kit answering that what it reads pays `actual` instead of `recipient`, read as the check
/// reads that answer.
private struct ForeignRecipientVerdict: OperationCheck {
    let recipient: String
    let actual: String

    func findings(of signable: SignableOperation) throws -> [OperationFinding] {
        try ChainKitValidationCheck.findings(
            [ValidationError.ForeignRecipient(payloadId: signable.operation.id, expected: recipient, actual: actual)],
            of: signable,
            intent: ChainKitValidationCheck.intent(of: signable)
        )
    }
}

/// What `check` finds, kept for each operation it reads.
private struct FindingsCheck: OperationCheck {
    actor Found {
        private(set) var all = [[OperationFinding]]()

        func append(_ findings: [OperationFinding]) {
            all.append(findings)
        }
    }

    let check: any OperationCheck
    let found = Found()

    init(reading check: any OperationCheck) {
        self.check = check
    }

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        let findings = try await check.findings(of: signable)
        await found.append(findings)
        return findings
    }
}

/// Finds a warning in whatever it reads, and keeps the account each was read from, key included.
private struct AccountCheck: OperationCheck {
    struct Read: Equatable {
        let address: String
        let assetId: String
        let publicKey: String?
        let intent: OperationIntent
    }

    actor Reads {
        private(set) var all = [Read]()

        func append(_ read: Read) {
            all.append(read)
        }
    }

    let calls: TronSwapCalls
    let reads = Reads()

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        let account = signable.account
        calls.record("review \(account.asset.id)")
        await reads.append(Read(address: account.addressDisplay, assetId: account.asset.id, publicKey: account.publicKey?.defaultHex, intent: signable.intent))
        return [OperationFinding(id: signable.operation.id, kind: "StubWarning", severity: .warning, title: "Finding")]
    }
}

private struct BootConfigurationServiceStub: BootConfigurationService {
    let bootConfigurations: BootConfigurations

    func getConfiguration() throws -> BootConfigurations {
        bootConfigurations
    }

    func loadConfiguration() async throws -> BootConfigurations {
        bootConfigurations
    }
}

private final class AppSettingsStub: TKAppSettings {
    var isConfirmButtonInsteadSlider = false
    var raffleIsNewUser: Bool?
}
