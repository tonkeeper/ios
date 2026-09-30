import BigInt
@testable import KeeperCore
import TonSwift
import TronSwift
import XCTest

final class MultichainSwapBatteryFeeRulesTests: XCTestCase {
    func testRelayableAssetsAreRecognisedPerChain() {
        XCTAssertEqual(relayedAsset(assetId: tonJettonAssetId), .tonJetton)
        XCTAssertEqual(relayedAsset(assetId: usdtAssetId, chain: .tron), .tron(.usdt))
        XCTAssertEqual(relayedAsset(assetId: "tron/mainnet/coin", chain: .tron), .tron(.trx))
    }

    /// The TON coin would have to reimburse the relayer in the very asset being spent, and any other
    /// TRC-20 has no resource estimate to price it with.
    func testAssetsWithNoRelayableFormAreRefused() {
        for assetId in [
            "ton/mainnet/coin",
            "ton/mainnet/trc20/0:jetton-master",
        ] {
            XCTAssertNil(relayedAsset(assetId: assetId), assetId)
        }
        for assetId in [
            "tron/mainnet/trc20/TOtherContract",
            "tron/mainnet/jetton/TContract",
        ] {
            XCTAssertNil(relayedAsset(assetId: assetId, chain: .tron), assetId)
        }
    }

    func testEverySwitchOffMakesTheSwapUnrelayable() {
        let cases: [(String, () -> MultichainSwapRelayedAsset?)] = [
            ("route needs an approval", { self.relayedAsset(requiresApproval: true) }),
            ("testnet wallet", { self.relayedAsset(wallet: self.makeWallet(network: .testnet)) }),
            ("no address on the chain", { self.relayedAsset(wallet: self.makeWallet(addresses: [])) }),
            ("not a multichain wallet", {
                self.relayedAsset(wallet: self.makeWallet(isMultichain: false))
            }),
        ]
        for (reason, subject) in cases {
            XCTAssertNil(subject(), reason)
        }
    }

    /// The battery switches speak about charges alone. They decide whether that one method is offered
    /// on top of a relayable swap, and the GRAM instant fee — which spends no charges — is not theirs
    /// to hide, exactly as the TRON send screen has it.
    func testBatterySwitchesOnlyDecideTheChargesMethod() {
        XCTAssertTrue(isBatteryAllowed())
        let cases: [(String, Bool)] = [
            ("remote battery flag", isBatteryAllowed(isBatteryEnabled: false)),
            ("remote battery send flag", isBatteryAllowed(isBatterySendEnabled: false)),
            (
                "wallet turned battery off for swaps",
                isBatteryAllowed(wallet: makeWallet(batterySettings: .init(isSwapTransactionEnable: false)))
            ),
        ]
        for (reason, isAllowed) in cases {
            XCTAssertFalse(isAllowed, reason)
        }
        XCTAssertNotNil(
            relayedAsset(wallet: makeWallet(batterySettings: .init(isSwapTransactionEnable: false)))
        )
    }

    /// The USDT send path hides battery entirely in a TRX-only region, so a TRON swap must not offer a
    /// method the send screen for the same asset refuses. TON is billed in charges either way.
    func testTRXOnlyRegionRefusesOnlyTron() {
        XCTAssertNil(
            relayedAsset(assetId: usdtAssetId, chain: .tron, isTRXOnlyRegion: true)
        )
        XCTAssertEqual(relayedAsset(isTRXOnlyRegion: true), .tonJetton)
    }

    func testOptionCarriesChargesAndExcess() {
        let option = MultichainSwapBatteryFeeRules.option(
            charges: 4,
            excessCharges: 1,
            availableCharges: .available(10)
        )

        XCTAssertEqual(option.cost, .batteryCharges(count: 4, excess: 1, isInsufficient: false))
    }

    /// A wallet that never used battery gets an estimate without a price. The row has to survive that,
    /// or the picker offers the chain's coin alone and there is nowhere to top the battery up from.
    func testUnpricedEstimateKeepsARefillableOption() {
        for charges in [nil, 0] as [Int?] {
            let option = MultichainSwapBatteryFeeRules.option(
                charges: charges,
                excessCharges: nil,
                availableCharges: .available(10)
            )

            XCTAssertEqual(option.cost, .batteryUnpriced)
            XCTAssertEqual(option.isInsufficient, true)
            XCTAssertEqual(option.method, .battery)
            XCTAssertNil(option.relayedFee)
        }
    }

    func testChargeSufficiencyFollowsTheReadBalance() {
        let cases: [(BatteryChargesAvailability, Bool)] = [
            (.available(10), false),
            (.available(3), true),
            (.unavailable, true),
            // A balance that could not be read must never read as "not enough".
            (.unknown, false),
        ]
        for (available, expected) in cases {
            let option = MultichainSwapBatteryFeeRules.option(
                charges: 4,
                excessCharges: nil,
                availableCharges: available
            )

            XCTAssertEqual(option.isInsufficient, expected, "\(available)")
        }
    }

    func testRequoteAtOrBelowTheConfirmedPriceIsSent() throws {
        for charges in [7, 5] {
            try MultichainSwapBatteryFeeRules.requireQuote(
                charges,
                confirmedCharges: 7,
                available: .available(10),
                payloadId: "main"
            )
        }
    }

    func testUnknownBalanceDoesNotBlockTheRequote() throws {
        try MultichainSwapBatteryFeeRules.requireQuote(
            7,
            confirmedCharges: 7,
            available: .unknown,
            payloadId: "main"
        )
    }

    /// The GRAM price moves with the TON rate between the confirmation and the send, so drift inside
    /// the tolerance is paid rather than bounced back to the user.
    func testGramRequoteWithinTheToleranceIsSent() throws {
        for amountNano: BigUInt in [99_000_000, 100_000_000, 105_000_000] {
            try MultichainSwapBatteryFeeRules.requireGramQuote(
                amountNano,
                confirmedAmountNano: 100_000_000,
                payloadId: "main"
            )
        }
    }

    func testGramRequotePastTheToleranceIsRefused() {
        do {
            try MultichainSwapBatteryFeeRules.requireGramQuote(
                105_000_001,
                confirmedAmountNano: 100_000_000,
                payloadId: "main"
            )
            XCTFail("expected the requote to be refused")
        } catch {
            guard case let .preparationFailed(kind, _) = error else {
                return XCTFail("expected a preparation failure, got \(error)")
            }
            XCTAssertEqual(kind, .unknown)
        }
    }

    /// The tolerance is a share of the confirmed price, so it cannot turn a free quote into a paid one.
    func testGramToleranceScalesWithTheConfirmedPrice() {
        XCTAssertThrowsError(
            try MultichainSwapBatteryFeeRules.requireGramQuote(
                1,
                confirmedAmountNano: 0,
                payloadId: "main"
            )
        )
    }

    func testTheRequoteIsRefusedWithTheKindTheScreenBranchesOn() {
        let cases: [(String, Int, BatteryChargesAvailability, MultichainSwapExecutionErrorKind)] = [
            ("above the confirmed price", 8, .available(100), .unknown),
            ("balance no longer covers it", 7, .available(6), .insufficientBalance),
            // `option` reads a non-positive count as no price at all, so the send path must not read
            // it as a quote that merely came in under the confirmed one.
            ("no price at all", 0, .available(100), .networkError),
            // A wallet battery cannot pay for at all is not the unknown the option was priced under.
            ("battery unavailable", 7, .unavailable, .insufficientBalance),
        ]
        for (reason, charges, available, expected) in cases {
            do {
                try MultichainSwapBatteryFeeRules.requireQuote(
                    charges,
                    confirmedCharges: 7,
                    available: available,
                    payloadId: "main"
                )
                XCTFail("expected the requote to be refused: \(reason)")
            } catch {
                guard case let .preparationFailed(kind, _) = error else {
                    XCTFail("expected a preparation failure for \(reason), got \(error)")
                    continue
                }
                XCTAssertEqual(kind, expected, reason)
            }
        }
    }
}

private extension MultichainSwapBatteryFeeRulesTests {
    var tonJettonAssetId: String {
        "ton/mainnet/jetton/0:jetton-master"
    }

    var usdtAssetId: String {
        "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)"
    }

    func relayedAsset(
        wallet: Wallet? = nil,
        assetId: String? = nil,
        chain: MultichainChain = .ton,
        requiresApproval: Bool = false,
        isTRXOnlyRegion: Bool = false
    ) -> MultichainSwapRelayedAsset? {
        MultichainSwapBatteryFeeRules.relayedAsset(
            wallet: wallet ?? makeWallet(addresses: [
                .init(chain: .ton, address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
                .init(chain: .tron, address: "TMultichainTronAddress"),
            ]),
            sourceAsset: makeAsset(assetId: assetId ?? tonJettonAssetId, chain: chain),
            requiresApproval: requiresApproval,
            isTRXOnlyRegion: isTRXOnlyRegion
        )
    }

    func isBatteryAllowed(
        wallet: Wallet? = nil,
        isBatteryEnabled: Bool = true,
        isBatterySendEnabled: Bool = true
    ) -> Bool {
        MultichainSwapBatteryFeeRules.isBatteryAllowed(
            wallet: wallet ?? makeWallet(),
            isBatteryEnabled: isBatteryEnabled,
            isBatterySendEnabled: isBatterySendEnabled
        )
    }

    func makeWallet(
        network: Network = .mainnet,
        batterySettings: BatterySettings = .init(),
        addresses: [MultichainWalletAddress] = [
            .init(chain: .ton, address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
            .init(chain: .tron, address: "TMultichainTronAddress"),
        ],
        isMultichain: Bool = true
    ) -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(
                network: network,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: .init(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: batterySettings,
            multichain: isMultichain
                ? .multichain(.init(walletId: "multichain-wallet-id", addresses: addresses))
                : nil
        )
    }

    func makeAsset(assetId: String, chain: MultichainChain) -> MultichainAsset {
        MultichainAsset(
            asset: .init(
                assetId: assetId,
                name: "Test asset",
                symbol: "TEST",
                decimals: chain == .ton ? 9 : 6,
                image: ""
            ),
            price: .init(prices: [:], diff24h: [:], diff7d: [:], diff30d: [:]),
            balance: 0
        )
    }
}
