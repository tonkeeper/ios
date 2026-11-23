import CryptoKit
import Foundation
@testable import KeeperCore
import XCTest

final class PerpsSecurityConfigRepositoryTests: XCTestCase {
    private let key = Curve25519.Signing.PrivateKey()
    private let store = MemoryStore()
    private let served = ServedBlock()

    private lazy var repository = PerpsSecurityConfigRepository(
        servedBlock: { [served] in served.block },
        store: store,
        trustedKeys: SecurityBlocks.trusting(key)
    )

    func testTheBlockTheBackendServesTodayVerifiesWithTheBuiltInKey() async throws {
        let production = PerpsSecurityConfigRepository(servedBlock: { Self.productionBlockV2 }, store: store)

        let verified = await production.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.version, 2)
        XCTAssertEqual(config.hermesDelegate, SecurityBlocks.hermesDelegate)
        XCTAssertEqual(config.changePubKeyContract, SecurityBlocks.lighterChangePubKey)
        XCTAssertEqual(config.hermesDelegateChains, ["eth", "bsc", "arb", "base", "polygon", "robinhood"])
        XCTAssertEqual(config.relayLighterAccounts, [731_033])
        XCTAssertEqual(config.relayTonDepositories, [TonDepositFixture.depository])
        XCTAssertEqual(config.relayBitcoinDepositories, [BitcoinPsbtFixture.depository])
        XCTAssertTrue(config.relayRouters.isEmpty)
        XCTAssertEqual(store.block, Self.productionBlockV2)
    }

    func testTheBlockWithRelayRoutersTheBackendServesTodayNamesEachByItsRoleOnEveryEvmChain() async throws {
        let block = try JSONDecoder().decode(PerpsSecurityBlock.self, from: Data(PerpsSecurityProductionBlocks.withRelayRoutersText.utf8))
        let production = PerpsSecurityConfigRepository(servedBlock: { block }, store: store)

        let verified = await production.verified()
        let config = try XCTUnwrap(verified)

        let roles: [String: PerpsRelayRouter] = [
            SecurityBlocks.relayRouter: .erc20Router,
            SecurityBlocks.relayApprovalProxy: .approvalProxy,
            SecurityBlocks.relayReceiver: .relayReceiver,
        ]
        var expected = Dictionary(uniqueKeysWithValues: ["arb", "avax", "base", "bsc", "eth", "polygon"].map { ($0, roles) })
        expected["robinhood"] = roles.filter { $0.value != .relayReceiver }
        XCTAssertEqual(config.relayRouters, expected)
        XCTAssertEqual(Set(config.relayEVMDepositories.keys), Set(expected.keys))
    }

    func testOnlyAnEvmAddressSignedWithOneKnownRoleOnAnEvmChainIsARelayRouter() async throws {
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(relayRouters: [
            SecurityBlocks.router("eth", SecurityBlocks.relayRouter.uppercased().replacingOccurrences(of: "0X", with: "0x"), "erc20_router"),
            SecurityBlocks.router("eth", SecurityBlocks.relayRouter, "erc20_router"),
            SecurityBlocks.router("eth", SecurityBlocks.relayApprovalProxy, "approval_proxy"),
            SecurityBlocks.router("eth", SecurityBlocks.relayApprovalProxy, "erc20_router"),
            SecurityBlocks.router("eth", SecurityBlocks.relayReceiver, "receiver"),
            SecurityBlocks.router("eth", "0x1234", "erc20_router"),
            SecurityBlocks.router("tron", TronFixture.router, "erc20_router"),
            SecurityBlocks.router("ton", SecurityBlocks.relayRouter, "erc20_router"),
            SecurityBlocks.router("bsc", SecurityBlocks.relayReceiver, "RELAY_RECEIVER"),
            ["chain": "base", "address": SecurityBlocks.relayReceiver],
            ["chain": "base", "address": SecurityBlocks.relayRouter, "type": 1],
            ["address": SecurityBlocks.relayRouter, "type": "erc20_router"],
            "not an entry",
            SecurityBlocks.router("arb", SecurityBlocks.relayReceiver, "relay_receiver"),
        ]))

        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.relayRouters, [
            "eth": [SecurityBlocks.relayRouter: .erc20Router],
            "arb": [SecurityBlocks.relayReceiver: .relayReceiver],
        ])
        XCTAssertEqual(config.relayLighterAccounts, [731_033])
    }

    func testAReadAfterTheDownloadTakesTheDownloadedBlockOverTheCachedOne() async throws {
        let cached = SecurityBlocks.signed(key, SecurityBlocks.payload(version: 2))
        let downloaded = SecurityBlocks.signed(key, SecurityBlocks.payload(version: 2, relayRouters: [
            SecurityBlocks.router("eth", SecurityBlocks.relayRouter, "erc20_router"),
        ]))
        let repository = PerpsSecurityConfigRepository(
            servedBlock: { cached },
            downloadedBlock: { downloaded },
            store: store,
            trustedKeys: SecurityBlocks.trusting(key)
        )

        let beforeDownload = await repository.verified()
        XCTAssertEqual(try XCTUnwrap(beforeDownload).relayRouters, [:])

        let afterDownload = await repository.verifiedAfterDownload()
        XCTAssertEqual(try XCTUnwrap(afterDownload).relayRouters, ["eth": [SecurityBlocks.relayRouter: .erc20Router]])
        XCTAssertEqual(store.block, downloaded)
    }

    func testRelaysBitcoinDepositoryIsReadAsBech32InLowerCaseOrAsBase58AsWritten() async throws {
        let base58 = "3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy"
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(relayDepositories: [
            ["chain": "btc", "address": BitcoinPsbtFixture.depository.uppercased()],
            ["chain": "btc", "address": base58],
            ["chain": "btc", "address": "bc1qZmtn0q92ayejt2hpffvlktcpmyy7vvsd06sefu"],
            ["chain": "btc", "address": "bc1qzmtn0q92ayejt2hpffvlktcpmyy7vvsd06sefb"],
            ["chain": "btc", "address": 7],
            ["chain": "lighter", "address": "731033"],
        ]))

        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.relayBitcoinDepositories, [BitcoinPsbtFixture.depository, base58])
        XCTAssertEqual(config.relayLighterAccounts, [731_033])
    }

    func testRelaysTonDepositoryIsReadInAnyAddressFormAsItsRawAddress() async throws {
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(relayDepositories: [
            ["chain": "ton", "address": TonDepositFixture.depositoryBounceable],
            ["chain": "lighter", "address": "731033"],
        ]))

        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.relayTonDepositories, [TonDepositFixture.depository])
        XCTAssertEqual(config.relayLighterAccounts, [731_033])
    }

    func testAMissingOrMalformedTonEntryLeavesTheRestOfTheBlockInForce() async throws {
        let payloads: [(String, Data)] = [
            ("no ton entry", SecurityBlocks.payload()),
            ("a ton entry that is no address", SecurityBlocks.payload(relayDepositories: [["chain": "ton", "address": "731035"], ["chain": "lighter", "address": "731033"]])),
            ("a ton entry without an address", SecurityBlocks.payload(relayDepositories: [["chain": "ton"], ["chain": "lighter", "address": "731033"]])),
            ("a ton entry whose address is a number", SecurityBlocks.payload(relayDepositories: [["chain": "ton", "address": 7], ["chain": "lighter", "address": "731033"]])),
        ]

        for (name, payload) in payloads {
            store.block = nil
            served.block = SecurityBlocks.signed(key, payload)

            let verified = await repository.verified()
            let config = try XCTUnwrap(verified, name)

            XCTAssertEqual(config.relayTonDepositories, [], name)
            XCTAssertEqual(config.relayLighterAccounts, [731_033], name)
            XCTAssertEqual(config.changePubKeyContract, SecurityBlocks.lighterChangePubKey, name)
        }
    }

    func testABlockWithoutRelaysLighterAccountStillHoldsWhatADepositChecks() async throws {
        let payloads: [(String, Data)] = [
            ("no relay_depositories", SecurityBlocks.payload(relayDepositories: nil)),
            ("no lighter entry", SecurityBlocks.payload(relayDepositories: [["chain": "eth", "address": SecurityBlocks.lighterGateway]])),
            ("a lighter entry that is no account index", SecurityBlocks.payload(relayDepositories: [["chain": "lighter", "address": "0x731033"]])),
            ("a lighter entry of account 0", SecurityBlocks.payload(relayDepositories: [["chain": "lighter", "address": "0"]])),
            ("a lighter entry with a leading zero", SecurityBlocks.payload(relayDepositories: [["chain": "lighter", "address": "0731033"]])),
            ("a lighter entry with a sign", SecurityBlocks.payload(relayDepositories: [["chain": "lighter", "address": "+731033"]])),
            ("a lighter entry with spaces", SecurityBlocks.payload(relayDepositories: [["chain": "lighter", "address": " 731033"]])),
            ("a lighter entry past Int64", SecurityBlocks.payload(relayDepositories: [["chain": "lighter", "address": "99999999999999999999"]])),
            ("relay_depositories that are not a list", SecurityBlocks.payload(relayDepositories: ["chain": "lighter", "address": "731033"])),
        ]

        for (name, payload) in payloads {
            store.block = nil
            served.block = SecurityBlocks.signed(key, payload)

            let verified = await repository.verified()
            let config = try XCTUnwrap(verified, name)

            XCTAssertEqual(config.changePubKeyContract, SecurityBlocks.lighterChangePubKey, name)
            XCTAssertEqual(config.hermesDelegate, SecurityBlocks.hermesDelegate, name)
            XCTAssertEqual(config.relayLighterAccounts, [], name)
            XCTAssertEqual(store.block, served.block, name)
        }
    }

    func testRelaysLighterAccountsAreReadFromTheLighterEntries() async throws {
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(relayDepositories: [
            ["chain": "eth", "address": "0x4cd00e387622c35bddb9b4c962c136462338bc31"],
            ["chain": "lighter", "address": "731033"],
            ["chain": "lighter", "address": "731034"],
            ["chain": "ton", "address": "731035"],
        ]))

        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.relayLighterAccounts, [731_033, 731_034])
    }

    func testAMalformedDepositoryDoesNotHideRelaysLighterAccount() async throws {
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(relayDepositories: [
            ["chain": "sol", "address": NSNull()],
            ["chain": "btc"],
            ["chain": 7, "address": 9],
            "not an entry",
            ["chain": "lighter", "address": "731033"],
        ]))

        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.relayLighterAccounts, [731_033])
    }

    func testABlockOfTheSameVersionThatGainedRelaysAccountReplacesTheKeptOne() async throws {
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(version: 2, relayDepositories: nil))
        _ = await repository.verified()

        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(version: 2))
        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.relayLighterAccounts, [731_033])
        XCTAssertEqual(store.block, served.block)
    }

    func testTheBlockWithMarketsTheBackendServesTodayListsEveryMarketWithItsScaleAndLimits() async throws {
        let block = try JSONDecoder().decode(PerpsSecurityBlock.self, from: Data(PerpsSecurityProductionBlocks.withMarketsText.utf8))
        let production = PerpsSecurityConfigRepository(servedBlock: { block }, store: store)

        let verified = await production.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.version, 2)
        XCTAssertEqual(config.markets.count, 243)
        XCTAssertEqual(
            config.markets[2],
            PerpsSignedMarket(
                marketId: 2,
                symbol: "SOL",
                priceDecimals: 3,
                sizeDecimals: 3,
                quoteDecimals: 6,
                minBaseAmount: "0.055",
                minQuoteAmount: "10.000000",
                maxLeverage: 25
            )
        )
        XCTAssertEqual(config.markets[28]?.maxLeverage, 0)
        XCTAssertEqual(config.markets[8286]?.symbol, "ASELS")
        XCTAssertEqual(config.relayLighterAccounts, [731_033])
    }

    func testABlockWithoutMarketsIsStillAConfigThatListsNone() async throws {
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(markets: nil))

        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertTrue(config.markets.isEmpty)
        XCTAssertEqual(config.relayLighterAccounts, [731_033])
    }

    func testOnlyAFullyReadableMarketListedOnceIsAMarket() async throws {
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(markets: [
            SecurityBlocks.market(),
            SecurityBlocks.market(id: 7, symbol: "XRP"),
            SecurityBlocks.market(id: 7, symbol: "XRP"),
            SecurityBlocks.market(id: 8, quoteDecimals: "6"),
            SecurityBlocks.market(id: 9, priceDecimals: 19),
            SecurityBlocks.market(id: 10, minBaseAmount: 0.1),
            SecurityBlocks.market(id: 11, minQuoteAmount: "1e1"),
            SecurityBlocks.market(id: 12, minBaseAmount: "-0.1"),
            SecurityBlocks.market(id: 13, maxLeverage: -1),
            SecurityBlocks.market(id: 14, maxLeverage: 10001),
            SecurityBlocks.market(id: 15, maxLeverage: 2.5),
            SecurityBlocks.market(id: 16, symbol: " "),
            SecurityBlocks.market(id: -1),
            SecurityBlocks.market(id: 17, minQuoteAmount: "1." + String(repeating: "0", count: 70)),
            SecurityBlocks.market(id: Int(Int16.max) + 1),
            42,
        ]))

        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(Set(config.markets.keys), [2])
        XCTAssertEqual(config.markets[2]?.minBaseAmount, "0.055")
    }

    func testTheLargestMarketIdASignedOrderCarriesIsStillAMarket() async throws {
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(markets: [SecurityBlocks.market(id: Int(Int16.max))]))

        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(Set(config.markets.keys), [Int64(Int16.max)])
    }

    func testEveryMarketTheCatalogListsTodayIsSignedUnderItsCatalogSymbolExceptTheThreeKoreanStocks() async throws {
        let block = try JSONDecoder().decode(PerpsSecurityBlock.self, from: Data(PerpsSecurityProductionBlocks.withMarketsText.utf8))
        let verified = await PerpsSecurityConfigRepository(servedBlock: { block }, store: store).verified()
        let signed = try XCTUnwrap(XCTUnwrap(verified).signedSymbols)

        let unlisted = Self.catalogSymbols20261112.filter { signed[$0.key] != $0.value }

        XCTAssertEqual(Self.catalogSymbols20261112.count, 204)
        XCTAssertEqual(unlisted, [160: "HYUNDAI", 161: "SKHYNIX", 162: "SAMSUNG"])
    }

    func testTheCurrentBlockNamesAMarketByItsSymbolIgnoringCase() throws {
        let repository = PerpsSecurityConfigRepository(
            servedBlock: { nil },
            currentBlock: { [key] in Self.antMarketsBlock(key) },
            store: store,
            trustedKeys: SecurityBlocks.trusting(key)
        )

        let config = try XCTUnwrap(repository.verifiedNow())

        XCTAssertEqual(config.marketId(symbol: "ant"), 10902)
        XCTAssertEqual(config.marketId(symbol: "Anthropic"), 193)
        XCTAssertNil(config.marketId(symbol: "GRAM"))
    }

    func testWithoutACurrentBlockTheKeptOneNamesTheMarket() {
        store.block = Self.antMarketsBlock(key)

        XCTAssertEqual(repository.verifiedNow()?.marketId(symbol: "ANT"), 10902)
    }

    private static func antMarketsBlock(_ key: Curve25519.Signing.PrivateKey) -> PerpsSecurityBlock {
        SecurityBlocks.signed(key, SecurityBlocks.payload(markets: [
            SecurityBlocks.market(id: 193, symbol: "ANTHROPIC"),
            SecurityBlocks.market(id: 10902, symbol: "ANT"),
        ]))
    }

    func testABlockWithoutMarketsListsNoSymbolsSoTheCatalogStaysAsServed() async throws {
        let production = PerpsSecurityConfigRepository(servedBlock: { Self.productionBlockV2 }, store: store)

        let verified = await production.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertTrue(config.markets.isEmpty)
        XCTAssertNil(config.signedSymbols)
    }

    func testTheBlockServedBeforeLighterMovedChangePubKeyIsNoConfig() async {
        let production = PerpsSecurityConfigRepository(servedBlock: { Self.productionBlockV1 }, store: store)

        let config = await production.verified()

        XCTAssertNil(config)
        XCTAssertNil(store.block)
    }

    func testAKeptBlockFromBeforeTheMoveGivesWayToTheServedOne() async throws {
        store.block = Self.productionBlockV1
        let production = PerpsSecurityConfigRepository(servedBlock: { Self.productionBlockV2 }, store: store)

        let verified = await production.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.changePubKeyContract, SecurityBlocks.lighterChangePubKey)
        XCTAssertEqual(store.block, Self.productionBlockV2)
    }

    func testAServedBlockSignedByTheTrustedKeyIsReadAndKept() async throws {
        served.block = SecurityBlocks.signed(key)

        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.hermesDelegate, SecurityBlocks.hermesDelegate)
        XCTAssertTrue(config.delegatesOnEthereum)
        XCTAssertEqual(store.block, served.block)
    }

    func testAddressesAreReadWithoutRegardToCase() async throws {
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(
            delegate: SecurityBlocks.hermesDelegate.uppercased().replacingOccurrences(of: "0X", with: "0x"),
            changePubKey: "0x183EF7195D443A3DA7EC1D7003BACA1FF490757D"
        ))

        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.hermesDelegate, SecurityBlocks.hermesDelegate)
        XCTAssertEqual(config.changePubKeyContract, SecurityBlocks.lighterChangePubKey)
    }

    func testNothingVerifiedIsNoConfig() async {
        let refused: [(String, PerpsSecurityBlock?)] = [
            ("nothing served", nil),
            ("not base64", PerpsSecurityBlock(payload: "%%%", signature: SecurityBlocks.signed(key).signature, keyVersion: 1)),
            ("a short signature", PerpsSecurityBlock(payload: SecurityBlocks.signed(key).payload, signature: Data(count: 63).base64EncodedString(), keyVersion: 1)),
            ("another key", SecurityBlocks.signed(Curve25519.Signing.PrivateKey())),
            ("an unknown key_version", SecurityBlocks.signed(key, keyVersion: 2)),
            ("another payload under the same signature", SecurityBlocks.signed(key, servedPayload: SecurityBlocks.payload(delegate: Self.otherAddress))),
            ("not mainnet", SecurityBlocks.signed(key, SecurityBlocks.payload(network: "testnet"))),
            ("version 0", SecurityBlocks.signed(key, SecurityBlocks.payload(version: 0))),
            ("no lighter_change_pub_key", SecurityBlocks.signed(key, SecurityBlocks.payload(changePubKey: nil))),
            ("lighter_change_pub_key off Ethereum", SecurityBlocks.signed(key, SecurityBlocks.payload(changePubKeyChain: "arb"))),
            ("a short lighter_change_pub_key", SecurityBlocks.signed(key, SecurityBlocks.payload(changePubKey: "0x183ef7"))),
            ("a short hermes_delegate", SecurityBlocks.signed(key, SecurityBlocks.payload(delegate: "0x24b576"))),
            ("no hermes_delegate", SecurityBlocks.signed(key, SecurityBlocks.payload(delegate: nil))),
            ("a payload that is not JSON", SecurityBlocks.signed(key, Data("not json".utf8))),
        ]

        for (name, block) in refused {
            served.block = block

            let config = await repository.verified()

            XCTAssertNil(config, name)
            XCTAssertNil(store.block, name)
        }
    }

    func testABlockThatFailsItsSignatureLeavesTheKeptOneInForce() async throws {
        served.block = SecurityBlocks.signed(key)
        _ = await repository.verified()
        let kept = store.block

        served.block = SecurityBlocks.signed(Curve25519.Signing.PrivateKey(), SecurityBlocks.payload(delegate: Self.otherAddress))
        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.hermesDelegate, SecurityBlocks.hermesDelegate)
        XCTAssertEqual(store.block, kept)
    }

    func testAKeptBlockReplacedInTheStoreIsVerifiedAgain() async {
        served.block = SecurityBlocks.signed(key)
        _ = await repository.verified()
        served.block = nil
        store.block = SecurityBlocks.signed(Curve25519.Signing.PrivateKey())

        let verified = await repository.verified()

        XCTAssertNil(verified)
    }

    func testTheSameBlocksReadTwiceGiveTheSameConfig() async throws {
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(version: 2))
        let first = await repository.verified()
        let second = await repository.verified()

        XCTAssertEqual(try XCTUnwrap(first).version, 2)
        XCTAssertEqual(first, second)
        XCTAssertEqual(store.block, served.block)
    }

    func testAnOlderVersionThanTheKeptOneIsRefused() async throws {
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(version: 2))
        _ = await repository.verified()
        let kept = store.block

        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(version: 1, delegate: Self.otherAddress))
        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.version, 2)
        XCTAssertEqual(config.hermesDelegate, SecurityBlocks.hermesDelegate)
        XCTAssertEqual(store.block, kept)
    }

    func testANewerVersionReplacesTheKeptOne() async throws {
        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(version: 1))
        _ = await repository.verified()

        served.block = SecurityBlocks.signed(key, SecurityBlocks.payload(version: 2, delegate: Self.otherAddress))
        let verified = await repository.verified()
        let config = try XCTUnwrap(verified)

        XCTAssertEqual(config.version, 2)
        XCTAssertEqual(config.hermesDelegate, Self.otherAddress)
        XCTAssertEqual(store.block, served.block)
    }

    func testAKeptBlockAlteredInStorageIsNoConfig() async {
        store.block = SecurityBlocks.signed(key, servedPayload: SecurityBlocks.payload(delegate: Self.otherAddress))

        let config = await repository.verified()

        XCTAssertNil(config)
    }

    func testTheBlockIsReadFromTheBootConfiguration() throws {
        let json = #"{"mainnet":{"perps_security":\#(Self.productionBlockV2Text)},"testnet":{}}"#

        let configurations = try JSONDecoder().decode(BootConfigurations.self, from: Data(json.utf8))
        let stored = try JSONDecoder().decode(BootConfigurations.self, from: JSONEncoder().encode(configurations))

        XCTAssertEqual(configurations.mainnet.perpsSecurity, Self.productionBlockV2)
        XCTAssertEqual(stored.mainnet.perpsSecurity, Self.productionBlockV2)
        XCTAssertNil(configurations.testnet.perpsSecurity)
    }

    func testAMalformedBlockInTheBootConfigurationIsNoBlock() throws {
        let json = #"{"mainnet":{"perps_security":{"payload":"e30=","signature":"AA==","key_version":"1"}},"testnet":{}}"#

        let configurations = try JSONDecoder().decode(BootConfigurations.self, from: Data(json.utf8))

        XCTAssertNil(configurations.mainnet.perpsSecurity)
    }

    private final class MemoryStore: PerpsSecurityConfigStore, @unchecked Sendable {
        var block: PerpsSecurityBlock?

        func keptBlock() -> PerpsSecurityBlock? {
            block
        }

        func keep(_ block: PerpsSecurityBlock) {
            self.block = block
        }
    }

    private final class ServedBlock: @unchecked Sendable {
        var block: PerpsSecurityBlock?
    }

    private static let otherAddress = "0xd1c44e466b70002ac54fb727ed7cbe8f92c782f1"
    private static let productionBlockV1Text = #"{"payload":"eyJ2ZXJzaW9uIjoxLCJpc3N1ZWRfYXQiOjE3OTQyMjM5OTYsIm5ldHdvcmsiOiJtYWlubmV0IiwiaG9zdHMiOnsicGVycHMiOiJodHRwczovL2FwcC5nZW8udG9ua2VlcGVyLmNvbS90ay1wZXJwcy9wdWJsaWMtYXBpL3YxIiwia2FuZGVsYWJyIjoiaHR0cHM6Ly9hcHAuZ2VvLnRvbmtlZXBlci5jb20va2FuZGVsYWJyL3B1YmxpYy1hcGkvdjEiLCJoZXJtZXMiOiJ3c3M6Ly9hcHAuZ2VvLnRvbmtlZXBlci5jb20vaGVybWVzL3B1YmxpYy1hcGkvdjEvd3MiLCJsaWdodGVyIjoiaHR0cHM6Ly9tYWlubmV0LnprbGlnaHRlci5lbGxpb3QuYWkifSwiZGV2aWNlX2F1dGhfaG9zdHMiOlsiYXBwLmdlby50b25rZWVwZXIuY29tIiwic3dhcC50b25rZWVwZXIuY29tIl0sImNvbnRyYWN0cyI6eyJsaWdodGVyX2dhdGV3YXkiOnsiY2hhaW4iOiJldGgiLCJhZGRyZXNzIjoiMHgzYjRkNzk0YTY2MzA0ZjEzMGE0ZGI4ZjI1NTFiMDA3MGRmY2Y1Y2E3In0sImhlcm1lc19kZWxlZ2F0ZSI6eyJhZGRyZXNzIjoiMHgyNGI1NzZiYzI3MTgyM2JmOWMyNGJlNjI3YjQzNjNiOWIwMDE5MWU5IiwiY2hhaW5zIjpbImV0aCIsImJzYyIsImFyYiIsImJhc2UiLCJwb2x5Z29uIiwicm9iaW5ob29kIl19fSwiaW50ZWdyYXRvcnMiOlt7ImludGVncmF0b3JfYWNjb3VudF9pbmRleCI6MjgxNDc0OTc2NDg3NzY0LCJtYXhfcGVycHNfdGFrZXJfZmVlIjoxMDAwLCJtYXhfcGVycHNfbWFrZXJfZmVlIjoxMDAwLCJtYXhfc3BvdF90YWtlcl9mZWUiOjAsIm1heF9zcG90X21ha2VyX2ZlZSI6MCwibWF4X2FwcHJvdmFsX3R0bF9tcyI6MzE1MzYwMDAwMDB9LHsiaW50ZWdyYXRvcl9hY2NvdW50X2luZGV4IjoyODE0NzQ5NzY0ODc3NjksIm1heF9wZXJwc190YWtlcl9mZWUiOjEwMDAsIm1heF9wZXJwc19tYWtlcl9mZWUiOjEwMDAsIm1heF9zcG90X3Rha2VyX2ZlZSI6MCwibWF4X3Nwb3RfbWFrZXJfZmVlIjowLCJtYXhfYXBwcm92YWxfdHRsX21zIjozMTUzNjAwMDAwMH0seyJpbnRlZ3JhdG9yX2FjY291bnRfaW5kZXgiOjI4MTQ3NDk3NjQ4Nzc3MCwibWF4X3BlcnBzX3Rha2VyX2ZlZSI6MTAwMCwibWF4X3BlcnBzX21ha2VyX2ZlZSI6MTAwMCwibWF4X3Nwb3RfdGFrZXJfZmVlIjowLCJtYXhfc3BvdF9tYWtlcl9mZWUiOjAsIm1heF9hcHByb3ZhbF90dGxfbXMiOjMxNTM2MDAwMDAwfV19","signature":"PiPHnzcZxVlcJYBuEU7PcXEduVe1yqTnw9NgHI6gJ1YY2gYxfZN8lS5JAid9lQwo3Z3j6LqlLLCMk+XeFvvSCw==","key_version":1}"#
    private static let productionBlockV2Text = #"{"payload":"eyJ2ZXJzaW9uIjoyLCJpc3N1ZWRfYXQiOjE3OTQyNDc1MjEsIm5ldHdvcmsiOiJtYWlubmV0IiwiaG9zdHMiOnsicGVycHMiOiJodHRwczovL2FwcC5nZW8udG9ua2VlcGVyLmNvbS90ay1wZXJwcy9wdWJsaWMtYXBpL3YxIiwia2FuZGVsYWJyIjoiaHR0cHM6Ly9hcHAuZ2VvLnRvbmtlZXBlci5jb20va2FuZGVsYWJyL3B1YmxpYy1hcGkvdjEiLCJoZXJtZXMiOiJ3c3M6Ly9hcHAuZ2VvLnRvbmtlZXBlci5jb20vaGVybWVzL3B1YmxpYy1hcGkvdjEvd3MiLCJsaWdodGVyIjoiaHR0cHM6Ly9tYWlubmV0LnprbGlnaHRlci5lbGxpb3QuYWkifSwiZGV2aWNlX2F1dGhfaG9zdHMiOlsiYXBwLmdlby50b25rZWVwZXIuY29tIiwic3dhcC50b25rZWVwZXIuY29tIl0sImNvbnRyYWN0cyI6eyJsaWdodGVyX2dhdGV3YXkiOnsiY2hhaW4iOiJldGgiLCJhZGRyZXNzIjoiMHgzYjRkNzk0YTY2MzA0ZjEzMGE0ZGI4ZjI1NTFiMDA3MGRmY2Y1Y2E3In0sImxpZ2h0ZXJfY2hhbmdlX3B1Yl9rZXkiOnsiY2hhaW4iOiJldGgiLCJhZGRyZXNzIjoiMHgxODNlZjcxOTVkNDQzYTNkYTdlYzFkNzAwM2JhY2ExZmY0OTA3NTdkIn0sImhlcm1lc19kZWxlZ2F0ZSI6eyJhZGRyZXNzIjoiMHgyNGI1NzZiYzI3MTgyM2JmOWMyNGJlNjI3YjQzNjNiOWIwMDE5MWU5IiwiY2hhaW5zIjpbImV0aCIsImJzYyIsImFyYiIsImJhc2UiLCJwb2x5Z29uIiwicm9iaW5ob29kIl19fSwicmVsYXlfZGVwb3NpdG9yaWVzIjpbeyJjaGFpbiI6ImFyYiIsImFkZHJlc3MiOiIweDRjZDAwZTM4NzYyMmMzNWJkZGI5YjRjOTYyYzEzNjQ2MjMzOGJjMzEifSx7ImNoYWluIjoiYXZheCIsImFkZHJlc3MiOiIweDRjZDAwZTM4NzYyMmMzNWJkZGI5YjRjOTYyYzEzNjQ2MjMzOGJjMzEifSx7ImNoYWluIjoiYmFzZSIsImFkZHJlc3MiOiIweDRjZDAwZTM4NzYyMmMzNWJkZGI5YjRjOTYyYzEzNjQ2MjMzOGJjMzEifSx7ImNoYWluIjoiYnNjIiwiYWRkcmVzcyI6IjB4NGNkMDBlMzg3NjIyYzM1YmRkYjliNGM5NjJjMTM2NDYyMzM4YmMzMSJ9LHsiY2hhaW4iOiJidGMiLCJhZGRyZXNzIjoiYmMxcXptdG4wcTkyYXllanQyaHBmZnZsa3RjcG15eTd2dnNkMDZzZWZ1In0seyJjaGFpbiI6ImV0aCIsImFkZHJlc3MiOiIweDRjZDAwZTM4NzYyMmMzNWJkZGI5YjRjOTYyYzEzNjQ2MjMzOGJjMzEifSx7ImNoYWluIjoibGlnaHRlciIsImFkZHJlc3MiOiI3MzEwMzMifSx7ImNoYWluIjoicG9seWdvbiIsImFkZHJlc3MiOiIweDRjZDAwZTM4NzYyMmMzNWJkZGI5YjRjOTYyYzEzNjQ2MjMzOGJjMzEifSx7ImNoYWluIjoicm9iaW5ob29kIiwiYWRkcmVzcyI6IjB4NGNkMDBlMzg3NjIyYzM1YmRkYjliNGM5NjJjMTM2NDYyMzM4YmMzMSJ9LHsiY2hhaW4iOiJ0b24iLCJhZGRyZXNzIjoiMDphYjc0NmIwMzRlYTAzNmI3YWM1MTQ3ODM3YTU3ODI3YmQzOTE3YmMzZjU1MDZkNDc0NzllODdlYzg3ZWYyNTU0In0seyJjaGFpbiI6InRyb24iLCJhZGRyZXNzIjoiVFh0RXM2dDJvVVdRc05vczdtNjhnYkhkRTlRNW42eDJvTiJ9XSwiaW50ZWdyYXRvcnMiOlt7ImludGVncmF0b3JfYWNjb3VudF9pbmRleCI6MjgxNDc0OTc2NDg3NzY0LCJtYXhfcGVycHNfdGFrZXJfZmVlIjoxMDAwLCJtYXhfcGVycHNfbWFrZXJfZmVlIjoxMDAwLCJtYXhfc3BvdF90YWtlcl9mZWUiOjAsIm1heF9zcG90X21ha2VyX2ZlZSI6MCwibWF4X2FwcHJvdmFsX3R0bF9tcyI6MzE1MzYwMDAwMDB9LHsiaW50ZWdyYXRvcl9hY2NvdW50X2luZGV4IjoyODE0NzQ5NzY0ODc3NjksIm1heF9wZXJwc190YWtlcl9mZWUiOjEwMDAsIm1heF9wZXJwc19tYWtlcl9mZWUiOjEwMDAsIm1heF9zcG90X3Rha2VyX2ZlZSI6MCwibWF4X3Nwb3RfbWFrZXJfZmVlIjowLCJtYXhfYXBwcm92YWxfdHRsX21zIjozMTUzNjAwMDAwMH0seyJpbnRlZ3JhdG9yX2FjY291bnRfaW5kZXgiOjI4MTQ3NDk3NjQ4Nzc3MCwibWF4X3BlcnBzX3Rha2VyX2ZlZSI6MTAwMCwibWF4X3BlcnBzX21ha2VyX2ZlZSI6MTAwMCwibWF4X3Nwb3RfdGFrZXJfZmVlIjowLCJtYXhfc3BvdF9tYWtlcl9mZWUiOjAsIm1heF9hcHByb3ZhbF90dGxfbXMiOjMxNTM2MDAwMDAwfV19","signature":"e3Ayj5gCn/+xtsErJAAf/Zwx3thinwW27+Q2y/luBXVSzkS2awo/RPQHNiUVPVunuz4dZHpjg1HCdJ1xi579AA==","key_version":1}"#
    // swiftlint:disable:next force_try
    private static let productionBlockV1 = try! JSONDecoder().decode(PerpsSecurityBlock.self, from: Data(productionBlockV1Text.utf8))
    // swiftlint:disable:next force_try
    private static let productionBlockV2 = try! JSONDecoder().decode(PerpsSecurityBlock.self, from: Data(productionBlockV2Text.utf8))
}

private enum SecurityBlocks {
    static let hermesDelegate = "0x24b576bc271823bf9c24be627b4363b9b00191e9"
    static let lighterGateway = "0x3b4d794a66304f130a4db8f2551b0070dfcf5ca7"
    static let lighterChangePubKey = "0x183ef7195d443a3da7ec1d7003baca1ff490757d"
    static let relayRouter = "0x0729e2a4716d9f7dd17858d5d504426d228697f7"
    static let relayApprovalProxy = "0x5567954cd026cebfe486062cb75848e0f1c12e58"
    static let relayReceiver = "0xa5f565650890fba1824ee0f21ebbbf660a179934"
    static let keyVersion = 1

    static func trusting(_ key: Curve25519.Signing.PrivateKey) -> [Int: Data] {
        [keyVersion: key.publicKey.rawRepresentation]
    }

    static func payload(
        version: Int = 1,
        network: String = "mainnet",
        delegate: String? = hermesDelegate,
        delegateChains: [String] = ["eth", "arb"],
        changePubKey: String? = lighterChangePubKey,
        changePubKeyChain: String = "eth",
        relayDepositories: Any? = [["chain": "lighter", "address": "731033"]],
        markets: Any? = nil,
        relayRouters: Any? = nil
    ) -> Data {
        var contracts: [String: Any] = ["lighter_gateway": ["chain": "eth", "address": lighterGateway]]
        if let changePubKey {
            contracts["lighter_change_pub_key"] = ["chain": changePubKeyChain, "address": changePubKey]
        }
        if let delegate {
            contracts["hermes_delegate"] = ["address": delegate, "chains": delegateChains]
        }
        var payload: [String: Any] = ["version": version, "issued_at": 1_794_223_996, "network": network, "contracts": contracts]
        if let relayDepositories {
            payload["relay_depositories"] = relayDepositories
        }
        if let markets {
            payload["markets"] = markets
        }
        if let relayRouters {
            payload["relay_routers"] = relayRouters
        }
        // swiftlint:disable:next force_try
        return try! JSONSerialization.data(withJSONObject: payload, options: .sortedKeys)
    }

    static func router(_ chain: String, _ address: String, _ type: String) -> [String: Any] {
        ["chain": chain, "address": address, "type": type]
    }

    static func market(
        id: Any = 2,
        symbol: Any = "SOL",
        priceDecimals: Any = 3,
        sizeDecimals: Any = 3,
        quoteDecimals: Any = 6,
        minBaseAmount: Any = "0.055",
        minQuoteAmount: Any = "10.000000",
        maxLeverage: Any = 25
    ) -> [String: Any] {
        [
            "market_id": id,
            "symbol": symbol,
            "price_decimals": priceDecimals,
            "size_decimals": sizeDecimals,
            "quote_decimals": quoteDecimals,
            "min_base_amount": minBaseAmount,
            "min_quote_amount": minQuoteAmount,
            "max_leverage": maxLeverage,
        ]
    }

    static func signed(
        _ key: Curve25519.Signing.PrivateKey,
        _ payload: Data = payload(),
        keyVersion: Int = keyVersion,
        servedPayload: Data? = nil
    ) -> PerpsSecurityBlock {
        // swiftlint:disable:next force_try
        let signature = try! key.signature(for: payload)
        return PerpsSecurityBlock(
            payload: (servedPayload ?? payload).base64EncodedString(),
            signature: signature.base64EncodedString(),
            keyVersion: keyVersion
        )
    }
}
