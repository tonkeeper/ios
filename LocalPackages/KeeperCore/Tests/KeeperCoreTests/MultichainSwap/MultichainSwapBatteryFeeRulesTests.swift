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

    /// A legacy wallet swaps on its own TON and TRON addresses, unregistered, and the relayer pays
    /// for it the way it pays for the USDT send of the same wallet.
    func testALegacySwapWalletIsRelayableOnItsOwnAddresses() {
        let legacy = makeSwapWallet(registration: .unregistered, keys: .legacy)

        XCTAssertEqual(relayedAsset(swapWallet: legacy, assetId: usdtAssetId, chain: .tron), .tron(.usdt))
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
            ("testnet wallet", { self.relayedAsset(swapWallet: self.makeSwapWallet(network: .testnet)) }),
            ("no address on the chain", { self.relayedAsset(swapWallet: self.makeSwapWallet(addresses: [])) }),
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
        ]
        for (reason, isAllowed) in cases {
            XCTAssertFalse(isAllowed, reason)
        }
        XCTAssertTrue(
            isBatteryAllowed(wallet: makeWallet(batterySettings: .init(isSwapTransactionEnable: false))),
            "a stored switch no longer turns the battery off"
        )
        XCTAssertNotNil(
            relayedAsset(swapWallet: makeSwapWallet(batterySettings: .init(isSwapTransactionEnable: false)))
        )
    }

    /// A Ledger signs on TRON the very transaction the battery relays; on TON the battery would have it sign what its
    /// TON app does not.
    func testALedgerIsRelayedOnTronAlone() {
        let ledger = WalletKind.Ledger(
            TonSwift.PublicKey(data: Data(repeating: 1, count: 32)),
            .v4R2,
            Wallet.LedgerDevice(deviceId: UUID().uuidString, deviceModel: "Flex", accountIndex: 0)
        )
        let swapWallet = makeSwapWallet(keys: .device, kind: ledger)

        XCTAssertEqual(relayedAsset(swapWallet: swapWallet, assetId: usdtAssetId, chain: .tron), .tron(.usdt))
        XCTAssertEqual(relayedAsset(swapWallet: swapWallet, assetId: "tron/mainnet/coin", chain: .tron), .tron(.trx))
        XCTAssertNil(relayedAsset(swapWallet: swapWallet, assetId: tonJettonAssetId))
        XCTAssertTrue(isBatteryAllowed(wallet: swapWallet.wallet, chain: .tron))
        XCTAssertFalse(isBatteryAllowed(wallet: swapWallet.wallet, chain: .ton))
    }

    /// The USDT send path hides battery entirely in a TRX-only region, so a TRON swap must not offer a
    /// method the send screen for the same asset refuses. TON is billed in charges either way.
    func testTRXOnlyRegionRefusesOnlyTron() {
        XCTAssertNil(
            relayedAsset(assetId: usdtAssetId, chain: .tron, isTRXOnlyRegion: true)
        )
        XCTAssertEqual(relayedAsset(isTRXOnlyRegion: true), .tonJetton)
    }

    /// The swap screen offers the battery where a relayed method would charge it: a jetton on TON, TRX or
    /// USDT on TRON, and any asset on an EVM chain the relayer serves.
    func testCoverageFollowsTheRelayedMethods() {
        let coverage = coverage()

        XCTAssertTrue(coverage.covers(makeAsset(assetId: tonJettonAssetId, chain: .ton)))
        XCTAssertTrue(coverage.covers(makeAsset(assetId: usdtAssetId, chain: .tron)))
        XCTAssertTrue(coverage.covers(makeAsset(assetId: "tron/mainnet/coin", chain: .tron)))
        XCTAssertTrue(coverage.covers(makeAsset(assetId: "bsc/mainnet/coin", chain: .bsc)))
        XCTAssertTrue(coverage.covers(makeAsset(assetId: "sol/mainnet/coin", chain: .sol)))
        let uncovered: [(String, MultichainAsset)] = [
            ("the TON coin", makeAsset(assetId: "ton/mainnet/coin", chain: .ton)),
            ("an EVM chain the relayer does not serve", makeAsset(assetId: "eth/mainnet/coin", chain: .eth)),
            ("an EVM chain the Hermes delegate does not run on", makeAsset(assetId: "avax/mainnet/coin", chain: .avax)),
            ("a chain with no relayed method", makeAsset(assetId: "btc/mainnet/coin", chain: .btc)),
        ]
        for (reason, asset) in uncovered {
            XCTAssertFalse(coverage.covers(asset), reason)
        }
    }

    func testCoverageEndsWithTheSwitchesTheRelayedMethodsObey() {
        let jetton = makeAsset(assetId: tonJettonAssetId, chain: .ton)
        let usdt = makeAsset(assetId: usdtAssetId, chain: .tron)
        let bnb = makeAsset(assetId: "bsc/mainnet/coin", chain: .bsc)

        for asset in [jetton, usdt, bnb] {
            XCTAssertFalse(coverage(isBatteryEnabled: false).covers(asset), "battery switched off remotely")
            XCTAssertTrue(
                coverage(batterySettings: .init(isSwapTransactionEnable: false)).covers(asset),
                "a stored switch no longer turns the battery off"
            )
        }
        XCTAssertFalse(coverage(isTRXOnlyRegion: true).covers(usdt))
        XCTAssertTrue(coverage(isTRXOnlyRegion: true).covers(jetton))
        XCTAssertFalse(coverage(keys: .legacy).covers(bnb), "EVM relaying signs with the HD keys")
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
        swapWallet: MultichainSwapWallet? = nil,
        assetId: String? = nil,
        chain: MultichainChain = .ton,
        requiresApproval: Bool = false,
        isTRXOnlyRegion: Bool = false
    ) -> MultichainSwapRelayedAsset? {
        MultichainSwapBatteryFeeRules.relayedAsset(
            swapWallet: swapWallet ?? makeSwapWallet(),
            sourceAsset: makeAsset(assetId: assetId ?? tonJettonAssetId, chain: chain),
            requiresApproval: requiresApproval,
            isTRXOnlyRegion: isTRXOnlyRegion
        )
    }

    func isBatteryAllowed(
        wallet: Wallet? = nil,
        chain: MultichainChain = .ton,
        isBatteryEnabled: Bool = true,
        isBatterySendEnabled: Bool = true
    ) -> Bool {
        MultichainSwapBatteryFeeRules.isBatteryAllowed(
            wallet: wallet ?? makeWallet(),
            chain: chain,
            isBatteryEnabled: isBatteryEnabled,
            isBatterySendEnabled: isBatterySendEnabled
        )
    }

    func coverage(
        isBatteryEnabled: Bool = true,
        isTRXOnlyRegion: Bool = false,
        batterySettings: BatterySettings = .init(),
        keys: MultichainSwapWallet.Keys = .hd
    ) -> MultichainSwapBatteryCoverage {
        MultichainSwapBatteryCoverage(
            swapWallet: makeSwapWallet(
                batterySettings: batterySettings,
                addresses: Self.addresses + [
                    .init(chain: .bsc, address: "0x0000000000000000000000000000000000000001"),
                    .init(chain: .avax, address: "0x0000000000000000000000000000000000000001"),
                    .init(chain: .sol, address: "9wFFyRfZBsuAha4YcuxcXLKwMxJR43S7fPfQLusDBzvT"),
                    .init(chain: .btc, address: "bc1qmultichainbtcaddress"),
                ],
                keys: keys
            ),
            isBatteryEnabled: isBatteryEnabled,
            isTRXOnlyRegion: isTRXOnlyRegion,
            relayedEVMChains: [.bsc, .avax, .sol]
        )
    }

    static let addresses: [MultichainWalletAddress] = [
        .init(chain: .ton, address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
        .init(chain: .tron, address: "TMultichainTronAddress"),
    ]

    func makeSwapWallet(
        network: Network = .mainnet,
        batterySettings: BatterySettings = .init(),
        addresses: [MultichainWalletAddress] = MultichainSwapBatteryFeeRulesTests.addresses,
        registration: MultichainSwapWallet.Registration = .registered(walletId: "multichain-wallet-id"),
        keys: MultichainSwapWallet.Keys = .hd,
        kind: WalletKind = .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
    ) -> MultichainSwapWallet {
        MultichainSwapWallet(
            wallet: makeWallet(network: network, batterySettings: batterySettings, kind: kind),
            addresses: addresses,
            registration: registration,
            keys: keys
        )
    }

    func makeWallet(
        network: Network = .mainnet,
        batterySettings: BatterySettings = .init(),
        kind: WalletKind = .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
    ) -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(
                network: network,
                kind: kind
            ),
            metaData: .init(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: batterySettings,
            multichain: .multichain(.init(walletId: "multichain-wallet-id", addresses: Self.addresses))
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
            price: .init(prices: [:], diff24h: [:], diff7d: [:]),
            balance: 0
        )
    }
}
