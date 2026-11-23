@preconcurrency import BigInt
import ChainKit
@testable import KeeperCore
import OperationReviewModels
import TKLocalize
import XCTest

/// chain-kit's validation as the gate runs it: what it finds is rated as Android rates it, worded
/// for the sheet, and read only while the flag is on.
final class ChainKitValidationCheckTests: XCTestCase {
    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    func test_aFindingIsRatedByItsClassAndAWarningIsOnlyInfoInTheWalletsOwnFlow() {
        let rated: [(error: ValidationError, wallet: OperationFinding.Severity, dapp: OperationFinding.Severity)] = [
            (ValidationError.ForeignRecipient(payloadId: "main", expected: Fixture.recipient, actual: Fixture.foreign), .danger, .danger),
            (ValidationError.WrongDecimals(asset: Fixture.usdt.assetId, expected: 6, actual: 18), .danger, .danger),
            (ValidationError.LargeApproval(payloadId: "main", asset: Fixture.usdt.assetId, spender: Fixture.foreign, amount: number("1"), limit: nil), .info, .warning),
            (ValidationError.PermissionShared(payloadId: "main", keys: [Fixture.foreign]), .info, .warning),
            (ValidationError.Malformed(payloadId: "main", part: "calldata"), .info, .warning),
            (ValidationError.OpaqueMessage(payloadId: "main"), .info, .warning),
            (ValidationError.Unknown(cause: nil), .info, .warning),
            (ValidationError.UnsupportedChain(chain: "future/mainnet"), .info, .warning),
            (ValidationError.BlindCall(payloadId: "main", target: Fixture.foreign), .info, .info),
        ]

        for (error, wallet, dapp) in rated {
            XCTAssertEqual(ChainKitValidationCheck.severity(of: error, within: .wallet), wallet, "\(type(of: error))")
            XCTAssertEqual(ChainKitValidationCheck.severity(of: error, within: .dapp), dapp, "\(type(of: error))")
        }
    }

    /// A wallet's own flow shows them as info, so they carry what kept the validator from reading
    /// for the gate to log under the flow's name; the check logs nothing itself.
    func test_aValidatorThatReadNothingSaysWhy() throws {
        let log = RecordedLog()
        defer { log.stop() }
        let signable = try signable()

        let findings = try ChainKitValidationCheck.findings(
            [
                ValidationError.Unknown(cause: nil),
                ValidationError.UnsupportedChain(chain: "future/mainnet"),
                ValidationError.BlindCall(payloadId: "main", target: Fixture.foreign),
            ],
            of: signable,
            intent: ChainKitValidationCheck.intent(of: signable)
        )

        XCTAssertEqual(findings.map(\.severity), [.info, .info, .info])
        XCTAssertEqual(findings.map { $0.failure != nil }, [true, true, false])
        XCTAssertTrue(findings[1].failure?.contains("No validator for future/mainnet") == true, String(describing: findings[1].failure))
        XCTAssertEqual(log.records.map(\.message), [])
    }

    /// Amounts read as the confirmation shows them, in the asset of the intent a finding names.
    func test_everyFindingIsKeptUnderItsOwnIdWithItsAmountsInTheAssetTheIntentLists() throws {
        let signable = try signable()
        let unlimited = number(String(repeating: "f", count: 64), radix: 16)

        let findings = try ChainKitValidationCheck.findings(
            [
                ValidationError.BlindCall(payloadId: "main", target: Fixture.router),
                ValidationError.Overspend(
                    payloadId: "main",
                    asset: Fixture.usdtContract,
                    limit: number("1250500000"),
                    actual: number("12505000000"),
                    approved: number("0")
                ),
                ValidationError.LargeApproval(payloadId: "main", asset: Fixture.usdt.assetId, spender: Fixture.router, amount: unlimited, limit: nil),
                ValidationError.Approval(payloadId: "main", asset: Fixture.unlisted, spender: Fixture.router, amount: number("1000000")),
            ],
            of: signable,
            intent: ChainKitValidationCheck.intent(of: signable)
        )

        XCTAssertEqual(findings.map(\.id), ["op-1:0", "op-1:1", "op-1:2", "op-1:3"])
        XCTAssertEqual(findings.map(\.kind), [
            "ChainKitValidationErrorBlindCall",
            "ChainKitValidationErrorOverspend",
            "ChainKitValidationErrorLargeApproval",
            "ChainKitValidationErrorApproval",
        ])
        XCTAssertEqual(findings.map(\.severity), [.info, .danger, .info, .info])
        XCTAssertEqual(findings.map(\.title), [
            TKLocales.OperationValidation.Finding.blindCall,
            TKLocales.OperationValidation.Finding.overspend,
            TKLocales.OperationValidation.Finding.largeApproval,
            TKLocales.OperationValidation.Finding.approval,
        ])
        XCTAssertEqual(findings.map(\.details), [
            nil,
            TKLocales.OperationValidation.amountInstead("12 505 USDT", "1 250.5 USDT"),
            TKLocales.OperationValidation.unlimited("USDT"),
            nil,
        ])
        XCTAssertEqual(findings.map(\.subject), [Fixture.router, Fixture.usdtContract, Fixture.router, Fixture.router])
    }

    func test_theIntentIsWhatChainKitHoldsTheOperationTo() throws {
        let wallet = try ChainKitValidationCheck.intent(of: signable())
        let dapp = try ChainKitValidationCheck.intent(of: signable(intent: .dapp))

        XCTAssertEqual(wallet.source, .wallet)
        XCTAssertEqual(wallet.to?.display.lowercased(), Fixture.recipient)
        let spend = try XCTUnwrap(wallet.spends?.first)
        XCTAssertEqual(wallet.spends?.count, 1)
        XCTAssertEqual(spend.asset.id, Fixture.usdt.assetId)
        XCTAssertEqual(spend.asset.symbol, "USDT")
        XCTAssertEqual(spend.asset.decimals.value, 6)
        XCTAssertEqual(spend.amount.description, "25000000")
        XCTAssertEqual(dapp.source, .dapp)
        XCTAssertNil(dapp.spends)
        XCTAssertNil(dapp.to)
    }

    func test_aRecipientOrAnAssetChainKitCannotReadIsAnErrorRatherThanACrash() throws {
        let unreadable: [OperationIntent] = [
            .wallet(spending: [Fixture.spend], to: "not an address"),
            .wallet(spending: [OperationIntent.Spend(assetId: "not/an/asset", symbol: "USDT", decimals: 6, amount: 1)], to: nil),
        ]

        for intent in unreadable {
            XCTAssertThrowsError(try ChainKitValidationCheck.intent(of: signable(intent: intent)))
        }
    }

    /// What chain-kit itself reads in the payment it builds: one to another address than the user
    /// agreed to is a danger.
    func test_aPaymentToAnotherAddressThanAgreedIsADanger() async throws {
        let check = ChainKitValidationCheck(client: client)

        let flagged = try await check.findings(of: transfer(to: Fixture.foreign))
        let agreed = try await check.findings(of: transfer(to: Fixture.recipient))

        let finding = try XCTUnwrap(flagged.first)
        XCTAssertEqual(flagged.count, 1)
        XCTAssertEqual(finding.id, "transfer:0")
        XCTAssertEqual(finding.severity, .danger)
        XCTAssertEqual(finding.title, TKLocales.OperationValidation.Finding.foreignRecipient)
        XCTAssertEqual(finding.subject?.lowercased(), Fixture.foreign)
        XCTAssertEqual(agreed, [])
    }

    /// The validator answers with all it found, not only the verdict it names first.
    func test_everyFindingChainKitMakesIsKept() async throws {
        let findings = try await ChainKitValidationCheck(client: client).findings(
            of: transfer(to: Fixture.foreign, intent: .send(500_000, of: Fixture.usdt, to: Fixture.recipient))
        )

        XCTAssertEqual(findings.map(\.id), ["transfer:0", "transfer:1"])
        XCTAssertEqual(findings.map(\.title), [
            TKLocales.OperationValidation.Finding.foreignRecipient,
            TKLocales.OperationValidation.Finding.overspend,
        ])
    }

    /// A relayer paid in the token spent takes its fee by a transfer in the batch it relays. Whether
    /// its payload states the fee or not, the transfer is held within the fee and the amount beside
    /// it, however the token's id is spelled.
    func test_aRelayersFeeInTheTokenSpentIsHeldWhetherItsPayloadStatesItOrNot() async throws {
        let account = try ChainKitOperationSender.account(of: MultichainWalletAddress(chain: .eth, address: GaslessFixtures.sender), holding: Fixture.usdt)
        let checksummed = MultichainAssetDetails(
            assetId: "eth/mainnet/erc20/\(GaslessFixtures.usdtContract)",
            name: "Tether USD",
            symbol: "USDT",
            decimals: 6,
            image: ""
        )

        for stated in [nil, "115304"] {
            let operation = try GaslessFixtures.relayedOperation(feeAssetId: Fixture.usdt.assetId, fee: stated, calls: [
                (GaslessFixtures.usdtContract, XCTUnwrap(EVMGaslessCall.erc20TransferData(recipient: Fixture.foreign, amount: 120_000))),
                (GaslessFixtures.usdtContract, XCTUnwrap(EVMGaslessCall.erc20TransferData(recipient: Fixture.recipient, amount: 25_000_000))),
            ]).operation
            for feeAsset in [Fixture.usdt, checksummed] {
                let intent = OperationIntent.wallet(spending: [Fixture.spend], relayerFee: .relayerFee(120_000, in: feeAsset), to: nil)
                let findings = try await ChainKitValidationCheck(client: client).findings(
                    of: SignableOperation(operation: operation, account: account, intent: intent, fidelity: .exact)
                )

                XCTAssertEqual(findings.filter { $0.severity > .info }, [], "\(feeAsset.assetId), stated \(stated ?? "none")")
            }
        }
    }

    /// chain-kit holds a fee a payload states to that quote itself: listed beside the spends as well,
    /// it would only widen what else the operation may take.
    func test_aRelayersFeeIsSpentOnlyByAnOperationWhosePayloadsStateNone() throws {
        let account = try ChainKitOperationSender.account(of: MultichainWalletAddress(chain: .eth, address: GaslessFixtures.sender), holding: Fixture.usdt)
        let intent = OperationIntent.wallet(spending: [Fixture.spend], relayerFee: .relayerFee(120_000, in: Fixture.usdt), to: nil)

        let unstated = try ChainKitValidationCheck.intent(of: SignableOperation(
            operation: GaslessFixtures.relayedOperation(feeAssetId: Fixture.usdt.assetId, fee: nil).operation,
            account: account,
            intent: intent,
            fidelity: .exact
        ))
        let stated = try ChainKitValidationCheck.intent(of: SignableOperation(
            operation: GaslessFixtures.relayedOperation(feeAssetId: Fixture.usdt.assetId, fee: "120000").operation,
            account: account,
            intent: intent,
            fidelity: .exact
        ))

        XCTAssertEqual(unstated.spends?.map(\.amount.description), ["25126000"])
        XCTAssertEqual(stated.spends?.map(\.amount.description), ["25000000"])
    }

    /// The amount shown is not the one signed, so nothing else of the operation is worth reading.
    func test_anAssetDescribedWithWrongDecimalsIsADangerAndTheOnlyFinding() async throws {
        let intent = OperationIntent.wallet(
            spending: [OperationIntent.Spend(assetId: Fixture.usdt.assetId, symbol: "USDT", decimals: 18, amount: 1_000_000)],
            to: Fixture.recipient
        )

        let findings = try await ChainKitValidationCheck(client: client).findings(of: transfer(to: Fixture.foreign, intent: intent))

        XCTAssertEqual(findings.map(\.severity), [.danger])
        XCTAssertEqual(findings.map(\.title), [TKLocales.OperationValidation.Finding.wrongDecimals])
    }

    /// The boot configuration is read at every review: once one that turns validation off loads, the
    /// next review builds nothing and nothing is validated.
    func test_whileTheFlagIsOffNothingIsBuiltOrValidated() async throws {
        let configuration = KeeperCore.Configuration.review(thenValidates: false)
        let gate = OperationGate(configuration: configuration, validatingWith: client)
        var builds = 0
        let build = { [self] () async throws -> [SignableOperation] in
            builds += 1
            return try await[transfer(to: Fixture.foreign)]
        }

        let validated = await gate.preview(.ask, build)
        _ = await configuration.loadConfigurations()
        let unvalidated = await gate.preview(.ask, build)
        try await gate.clear(.ask, consent: .refuse, build)

        XCTAssertEqual(validated?.severity, .danger)
        XCTAssertNil(unvalidated)
        XCTAssertEqual(builds, 1)
        XCTAssertTrue(gate.checks().isEmpty)
    }
}

private extension ChainKitValidationCheckTests {
    /// What the wallet signs to send 1 USDT to `recipient`, held to sending it to the address agreed.
    func transfer(
        to recipient: String,
        intent: OperationIntent = .send(1_000_000, of: Fixture.usdt, to: Fixture.recipient)
    ) async throws -> SignableOperation {
        try await SignableOperation.transfer(
            from: Fixture.account(),
            to: recipient,
            amount: number("1000000"),
            memo: nil,
            isMax: false,
            intent: intent,
            fidelity: .converted,
            client: client
        )
    }

    func signable(intent: OperationIntent = .wallet(spending: [Fixture.spend], to: Fixture.recipient)) throws -> SignableOperation {
        try SignableOperation(
            operation: ChainKitOperationSender.parse(
                id: "op-1",
                payloads: #"[{"chain_id":"eth/mainnet","id":"main","type":"main","version":1,"meta":{"to":"\#(Fixture.recipient)","value":"0"}}]"#
            ),
            account: Fixture.account(),
            intent: intent,
            fidelity: .exact
        )
    }

    func number(_ value: String, radix: Int32 = 10) -> BignumBigInteger {
        BignumBigInteger.Companion.shared.parseString(string: value, base: radix)
    }
}

private enum Fixture {
    static let sender = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
    static let recipient = "0x3b4d794a66304f130a4db8f2551b0070dfcf5ca7"
    static let foreign = "0x00000000000000000000000000000000000000aa"
    static let router = "0x00000000000000000000000000000000000000ef"
    static let usdtContract = "0xdac17f958d2ee523a2206206994597c13d831ec7"
    static let unlisted = "eth/mainnet/erc20/0x00000000000000000000000000000000000000bb"
    static let usdt = MultichainAssetDetails(assetId: "eth/mainnet/erc20/\(usdtContract)", name: "Tether USD", symbol: "USDT", decimals: 6, image: "")
    static let spend = OperationIntent.Spend(25_000_000, of: usdt)

    static func account() throws -> ChainKit.Account {
        try ChainKitOperationSender.account(of: MultichainWalletAddress(chain: .eth, address: sender), holding: usdt)
    }
}
