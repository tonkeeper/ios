@testable import App
@testable import KeeperCore
import TKCore
import TKLogging
import TonSwift
import XCTest

@MainActor
final class EarnDappAnalyticsTests: XCTestCase {
    func test_signingStagesAreReportedAsTheirEvents() {
        let spy = AnalyticsServiceSpy()
        let analytics = makeAnalytics(spy: spy)
        let page = URL(string: "https://vaults.fyi/earn/base/0xVAULT")

        analytics.logSigning(EarnSigningEvent(method: .ethSendTransaction, chain: .base, pageURL: page, stage: .requested))
        analytics.logSigning(EarnSigningEvent(method: .ethSendTransaction, chain: .base, pageURL: page, stage: .signed))
        analytics.logSigning(EarnSigningEvent(method: .personalSign, chain: .base, pageURL: page, stage: .rejected))

        XCTAssertEqual(spy.events.map(\.name), ["earn_sign_request", "earn_sign_success", "earn_sign_rejected"])
        XCTAssertEqual(spy.events.map { $0.args["method"] as? String }, ["send_transaction", "send_transaction", "personal_sign"])
        XCTAssertEqual(spy.events.first?.args["from"] as? String, "earn_featured")
        XCTAssertEqual(spy.events.first?.args["chain"] as? String, "base")
        XCTAssertEqual(spy.events.map { $0.args["vault_id"] as? String }, Array(repeating: "base/mainnet/erc20/0xvault", count: 3))
    }

    func test_failuresCarryTheCodeOfTheirError() {
        let spy = AnalyticsServiceSpy()
        let analytics = makeAnalytics(spy: spy)
        let failures: [EarnSigningFailure] = [
            .noAccount,
            .invalidRequest(.invalidParams(method: .ethSignTypedDataV4, reason: "missing domain")),
            .invalidRequest(.chainMismatch(expected: .eth, actual: "eip155:8453")),
            .signer(.failedToCalculateFee(reason: "rpc")),
            .signer(.mnemonic(reason: "locked")),
            .signer(.failedToSend(reason: "insufficient funds")),
            .unexpectedResponse,
        ]

        for failure in failures {
            analytics.logSigning(EarnSigningEvent(method: .ethSignTypedDataV4, chain: .eth, pageURL: nil, stage: .failed(failure)))
        }

        XCTAssertEqual(Set(spy.events.map(\.name)), ["earn_sign_failed"])
        XCTAssertEqual(
            spy.events.map { $0.args["error_code"] as? String },
            [
                "no_account", "invalid_params", "chain_mismatch", "failed_to_calculate_fee", "mnemonic", "failed_to_send",
                "unexpected_response",
            ]
        )
        XCTAssertEqual(
            spy.events.map { $0.args["error_message"] as? String },
            [nil, "missing domain", nil, "rpc", "locked", "insufficient funds", nil]
        )
        XCTAssertEqual(spy.events.first?.args["method"] as? String, "sign_typed_data")
        XCTAssertNil(spy.events.first?.args["vault_id"])
    }

    func test_failureReasonLeavesOutAddressesAndHashes() {
        let spy = AnalyticsServiceSpy()
        let analytics = makeAnalytics(spy: spy)
        let address = "0x52908400098527886E0F7030069857D2E4169EE7"
        let hash = String(repeating: "ab", count: 32)
        let failures: [EarnSigningFailure] = [
            .signer(.failedToSend(reason: "insufficient funds: address \(address) have 1 want 2, tx 0x\(hash)")),
            .signer(.invalidTransaction(reason: "invalid sender address: \(address.lowercased())")),
            .signer(.senderAddressMismatch(expected: address, actual: "0x8617E340B3D01FA5F11F306F4090FD50E238070D")),
            .signer(.missingMultichainAddress(chain: .eth, walletId: "wallet-id")),
        ]

        for failure in failures {
            analytics.logSigning(EarnSigningEvent(method: .ethSendTransaction, chain: .eth, pageURL: nil, stage: .failed(failure)))
        }

        XCTAssertEqual(
            spy.events.map { $0.args["error_message"] as? String },
            ["insufficient funds: address <hex> have 1 want 2, tx <hex>", "invalid sender address: <hex>", nil, nil]
        )
    }

    func test_closeReportsHowTheUserLeftAndHowLongTheyStayed() {
        let spy = AnalyticsServiceSpy()

        makeAnalytics(spy: spy).logClose(exitMethod: .closeButton, durationMs: 42000)

        XCTAssertEqual(spy.events.map(\.name), ["earn_close"])
        XCTAssertEqual(spy.events.first?.args["from"] as? String, "earn_featured")
        XCTAssertEqual(spy.events.first?.args["exit_method"] as? String, "close_button")
        XCTAssertEqual(spy.events.first?.args["duration_ms"] as? Int, 42000)
    }

    func test_pageEventGoesThroughWithItsDeclaredPropertiesOnly() {
        let spy = AnalyticsServiceSpy()

        makeAnalytics(spy: spy).logPageEvent(
            name: "earn_deposit_success",
            params: [
                "vault_id": vault,
                "amount_usd": 12.5,
                "tx_hash": "0x" + String(repeating: "ab", count: 32),
                "platform": "web",
            ]
        )

        XCTAssertEqual(spy.events.map(\.name), ["earn_deposit_success"])
        let args = spy.events.first?.args
        XCTAssertEqual(args?["vault_id"] as? String, vault)
        XCTAssertEqual(args?["amount_usd"] as? Double, 12.5)
        XCTAssertNil(args?["tx_hash"])
        XCTAssertNotEqual(args?["platform"] as? String, "web")
    }

    func test_pageEventOutsideTheSchemaGoesOutAsSentAndIsReported() {
        let spy = AnalyticsServiceSpy()
        let address = "0x52908400098527886E0F7030069857D2E4169EE7"

        let records = recordingLog {
            makeAnalytics(spy: spy).logPageEvent(
                name: "earn_debug_state",
                params: [
                    "step": "review",
                    "attempt": 2,
                    "vault_id": vault,
                    "account": address,
                    "link": "https://basescan.org/address/\(address)",
                ]
            )
        }

        XCTAssertEqual(spy.events.map(\.name), ["earn_debug_state"])
        let args = spy.events.first?.args
        XCTAssertEqual(args?["step"] as? String, "review")
        XCTAssertEqual(args?["attempt"] as? Int, 2)
        XCTAssertEqual(args?["vault_id"] as? String, vault)
        XCTAssertEqual(args?["account"] as? String, "<hex>")
        XCTAssertEqual(args?["link"] as? String, "https://basescan.org/address/<hex>")
        XCTAssertEqual(records.map(\.severity), [.error])
        XCTAssertEqual(records.first?.extraInfo["event"], "earn_debug_state")
    }

    func test_pageEventMissingARequiredPropertyGoesOutAsSentAndIsReported() {
        let spy = AnalyticsServiceSpy()

        let records = recordingLog {
            makeAnalytics(spy: spy).logPageEvent(name: "earn_deposit_success", params: ["vault_id": vault])
        }

        XCTAssertEqual(spy.events.map(\.name), ["earn_deposit_success"])
        XCTAssertEqual(spy.events.first?.args["vault_id"] as? String, vault)
        XCTAssertEqual(records.map(\.severity), [.error])
        XCTAssertEqual(records.first?.extraInfo["event"], "earn_deposit_success")
    }

    func test_declaredPageEventIsNotReported() {
        let spy = AnalyticsServiceSpy()

        let records = recordingLog {
            makeAnalytics(spy: spy).logPageEvent(name: "earn_history_viewed", params: ["vault_id": vault])
        }

        XCTAssertEqual(spy.events.map(\.name), ["earn_history_viewed"])
        XCTAssertTrue(records.isEmpty)
    }

    func test_pageEventKeepsTheTypesOfItsProperties() {
        let spy = AnalyticsServiceSpy()

        makeAnalytics(spy: spy).logPageEvent(
            name: "earn_vault_selected",
            params: [
                "vault_id": vault,
                "is_initial_route": true,
                "asset": "base/mainnet/erc20/0x833589fcd6edb6e08f4c7c32d4f71b54bda02913",
                "apy": 4.25,
                "tvl_usd": 1_000_000,
            ]
        )

        let args = spy.events.first?.args
        XCTAssertEqual(args?["is_initial_route"] as? Bool, true)
        XCTAssertEqual(args?["apy"] as? Double, 4.25)
        XCTAssertEqual(args?["tvl_usd"] as? Double, 1_000_000)
    }

    func test_pageEventTextLeavesOutAddressesAndHashes() {
        let spy = AnalyticsServiceSpy()
        let analytics = makeAnalytics(spy: spy)
        let address = "0x52908400098527886E0F7030069857D2E4169EE7"

        analytics.logPageEvent(
            name: "earn_deposit_failed",
            params: ["vault_id": vault, "error_code": "reverted", "error_message": "execution reverted for \(address)"]
        )
        analytics.logPageEvent(name: "earn_external_link_clicked", params: ["url": "https://basescan.org/address/\(address)"])

        XCTAssertEqual(spy.events.map(\.name), ["earn_deposit_failed", "earn_external_link_clicked"])
        XCTAssertEqual(spy.events.first?.args["vault_id"] as? String, vault)
        XCTAssertEqual(spy.events.first?.args["error_message"] as? String, "execution reverted for <hex>")
        XCTAssertEqual(spy.events.last?.args["url"] as? String, "https://basescan.org/address/<hex>")
    }

    func test_onlyPageEventsAreMarkedAsSentFromTheVaultsFyiWebView() {
        let spy = AnalyticsServiceSpy()
        let analytics = makeAnalytics(spy: spy)

        analytics.logPageEvent(name: "earn_history_viewed", params: ["vault_id": vault])
        _ = recordingLog {
            analytics.logPageEvent(name: "earn_debug_state", params: ["isExternalWebView": 0, "eventProvider": "debug"])
        }
        analytics.logClose(exitMethod: .page, durationMs: 1000)

        XCTAssertEqual(spy.events.map(\.name), ["earn_history_viewed", "earn_debug_state", "earn_close"])
        XCTAssertEqual(spy.events.map { $0.args["isExternalWebView"] as? Int }, [1, 1, nil])
        XCTAssertEqual(spy.events.map { $0.args["eventProvider"] as? String }, ["vaults.fyi", "vaults.fyi", nil])
    }

    func test_sentTransactionIsReportedAsInjectedByTheEarnPage() {
        let spy = AnalyticsServiceSpy()
        let analytics = makeAnalytics(spy: spy)

        analytics.logTransactionSent(
            wallet: wallet,
            chain: .arb,
            transaction: WalletConnectEVMTransaction(
                from: nil,
                to: "0x2222222222222222222222222222222222222222",
                data: "0x6e553f65",
                value: "0x0",
                nonce: nil,
                gas: nil,
                gasPrice: nil,
                maxFeePerGas: nil,
                maxPriorityFeePerGas: nil
            )
        )

        XCTAssertEqual(spy.events.map(\.name), ["transaction_sent"])
        XCTAssertEqual(spy.events.first?.args["initiated_by"] as? String, "evm_injected")
        XCTAssertEqual(spy.events.first?.args["asset"] as? String, "arb/mainnet/coin")
        XCTAssertEqual(spy.events.first?.args["dapp_url"] as? String, "vaults.fyi")
    }
}

private extension EarnDappAnalyticsTests {
    var vault: String {
        "base/mainnet/erc20/0xc1256ae5ff1cf2719d4937adb3bbccab2e00a2ca"
    }

    var wallet: Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "multichain-wallet",
                    addresses: [
                        MultichainWalletAddress(chain: .arb, address: "0x1111111111111111111111111111111111111111"),
                    ]
                )
            )
        )
    }

    func recordingLog(_ body: () -> Void) -> [LogRecord] {
        let backend = RecordingLogBackend()
        let configuration = Log.configuration
        defer { Log.configuration = configuration }
        Log.configuration = LoggingConfiguration(minimumSeverity: .error, defaultSubsystem: "test", backends: [backend])
        body()
        return backend.records
    }

    func makeAnalytics(spy: AnalyticsServiceSpy) -> EarnDappAnalytics {
        let coreAssembly = TKCore.CoreAssembly()
        return EarnDappAnalytics(
            analyticsProvider: AnalyticsProvider(
                analyticsServices: [spy],
                uniqueIdProvider: coreAssembly.uniqueIdProvider,
                appInfoProvider: coreAssembly.appInfoProvider,
                keysCountryCodeProvider: coreAssembly.keysCountryCodeProvider
            ),
            from: .earnFeatured,
            utm: .empty,
            dappUrl: "vaults.fyi"
        )
    }
}

private final class AnalyticsServiceSpy: AnalyticsService {
    private(set) var events = [(name: String, args: [String: Any])]()

    func logEvent(name: String, args: [String: Any]) {
        events.append((name: name, args: args))
    }
}

private final class RecordingLogBackend: LogBackend {
    private(set) var records = [LogRecord]()

    func log(_ record: LogRecord) {
        records.append(record)
    }
}
