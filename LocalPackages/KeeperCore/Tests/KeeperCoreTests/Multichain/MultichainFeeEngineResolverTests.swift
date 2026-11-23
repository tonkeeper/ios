@testable import KeeperCore
import TonSwift
import TronSwift
import XCTest

final class MultichainFeeEngineResolverTests: XCTestCase {
    func testUSDTTRC20UsesTronEngineWithMultichainAddress() {
        let wallet = makeWallet(addresses: [
            .init(chain: .tron, address: "TMultichainTronAddress"),
        ])

        let engine = resolve(
            asset: makeAsset(assetId: "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)"),
            wallet: wallet
        )

        XCTAssertEqual(engine, .tronUSDT(tronAddress: "TMultichainTronAddress"))
    }

    func testTONJettonUsesJettonEngine() {
        let wallet = makeWallet(addresses: [
            .init(chain: .ton, address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
        ])

        let engine = resolve(
            asset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
            wallet: wallet
        )

        XCTAssertEqual(engine, .tonJetton(master: "0:jetton-master"))
    }

    func testEVMAssetOnARelayedChainUsesTheEVMEngine() {
        let wallet = makeWallet(addresses: [
            .init(chain: .eth, address: "0x0eE3CdEE4f010BF6c49aF86E9e67ef2bc80a508b"),
        ])

        XCTAssertEqual(
            resolve(
                asset: makeAsset(assetId: "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"),
                wallet: wallet
            ),
            .evm(chain: .eth)
        )
        XCTAssertEqual(
            resolve(asset: makeAsset(assetId: "eth/mainnet/coin"), wallet: wallet),
            .evm(chain: .eth)
        )
    }

    func testSolanaGoesToTheRelayerOnlyWhileTheRelayerServesIt() {
        let wallet = makeWallet(addresses: [
            .init(chain: .sol, address: "9wFFyRfZBsuAha4YcuxcXLKwMxJR43S7fPfQLusDBzvT"),
        ])
        let sol = makeAsset(assetId: "sol/mainnet/coin")
        let usdt = makeAsset(assetId: "sol/mainnet/spl/Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB")

        XCTAssertEqual(resolve(asset: sol, wallet: wallet, relayedEVMChains: [.eth, .sol]), .evm(chain: .sol))
        XCTAssertEqual(resolve(asset: usdt, wallet: wallet, relayedEVMChains: [.eth, .sol]), .evm(chain: .sol))
        XCTAssertEqual(resolve(asset: sol, wallet: wallet, relayedEVMChains: [.eth]), .chainKit)
    }

    func testEVMChainTheRelayerDoesNotServeKeepsChainKitEngine() {
        let wallet = makeWallet(addresses: [
            .init(chain: .bsc, address: "0x0eE3CdEE4f010BF6c49aF86E9e67ef2bc80a508b"),
        ])
        let asset = makeAsset(assetId: "bsc/mainnet/bep20/0x55d398326f99059ff775485246999027b3197955")

        XCTAssertEqual(resolve(asset: asset, wallet: wallet, relayedEVMChains: [.eth, .arb, .base]), .chainKit)
        XCTAssertEqual(resolve(asset: asset, wallet: wallet, relayedEVMChains: [.bsc]), .evm(chain: .bsc))
    }

    func testTheRelayedChainsAreReadWhenAnEVMEngineIsResolved() async {
        let wallet = makeWallet(addresses: [
            .init(chain: .eth, address: "0x0eE3CdEE4f010BF6c49aF86E9e67ef2bc80a508b"),
        ])
        let asset = makeAsset(assetId: "eth/mainnet/coin")
        var relayedEVMChains: Set<MultichainChain>? = []
        let resolver = MultichainFeeEngineResolver(relayedEVMChains: { relayedEVMChains })

        let before = await resolver.resolve(asset: asset, wallet: wallet)
        relayedEVMChains = [.eth]
        let after = await resolver.resolve(asset: asset, wallet: wallet)

        XCTAssertEqual(before, .init(engine: .chainKit, isSettled: true))
        XCTAssertEqual(after, .init(engine: .evm(chain: .eth), isSettled: true))
    }

    func testAnEVMEngineIsProvisionalWhileTheRelayerConfigIsUnknown() async {
        let wallet = makeWallet(addresses: [
            .init(chain: .eth, address: "0x0eE3CdEE4f010BF6c49aF86E9e67ef2bc80a508b"),
        ])
        let resolver = MultichainFeeEngineResolver(relayedEVMChains: { nil })

        let resolution = await resolver.resolve(asset: makeAsset(assetId: "eth/mainnet/coin"), wallet: wallet)

        XCTAssertEqual(resolution, .init(engine: .chainKit, isSettled: false))
    }

    func testASolanaSendSwitchedOffNeverWaitsForTheRelayerConfigAndIsAskedAgain() async {
        let wallet = makeWallet(addresses: [
            .init(chain: .sol, address: "HLT1cw2FTfgMJ2DNZHQpcr19n5bqrfqBGxEuFSEWgE4r"),
        ])
        var reads = 0
        let resolver = MultichainFeeEngineResolver(
            relayedEVMChains: {
                reads += 1
                return [.sol]
            },
            relays: { $0 != .sol }
        )

        let resolution = await resolver.resolve(asset: makeAsset(assetId: "sol/mainnet/coin"), wallet: wallet)

        XCTAssertEqual(resolution, .init(engine: .chainKit, isSettled: false))
        XCTAssertEqual(reads, 0)
    }

    func testATONOrTRONEngineNeverWaitsForTheRelayerConfig() async {
        let wallet = makeWallet(addresses: [
            .init(chain: .ton, address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
            .init(chain: .tron, address: "TMultichainTronAddress"),
        ])
        var reads = 0
        let resolver = MultichainFeeEngineResolver(relayedEVMChains: {
            reads += 1
            return nil
        })

        let jetton = await resolver.resolve(asset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"), wallet: wallet)
        let usdt = await resolver.resolve(
            asset: makeAsset(assetId: "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)"),
            wallet: wallet
        )

        XCTAssertEqual(jetton, .init(engine: .tonJetton(master: "0:jetton-master"), isSettled: true))
        XCTAssertEqual(usdt, .init(engine: .tronUSDT(tronAddress: "TMultichainTronAddress"), isSettled: true))
        XCTAssertEqual(reads, 0)
    }

    func testEVMAssetWithoutAnAddressKeepsChainKitEngine() {
        let wallet = makeWallet(addresses: [
            .init(chain: .ton, address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
        ])

        let engine = resolve(
            asset: makeAsset(assetId: "eth/mainnet/coin"),
            wallet: wallet
        )

        XCTAssertEqual(engine, .chainKit)
    }

    func testALedgerSendsTONThroughTheTONEnginesUSDTOnTRONThroughTheBatteryOneAndEVMThroughChainKit() {
        let wallet = makeWallet(
            addresses: [
                .init(chain: .ton, address: "UQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJKZ"),
                .init(chain: .eth, address: "0x0eE3CdEE4f010BF6c49aF86E9e67ef2bc80a508b"),
                .init(chain: .tron, address: "TLedgerTronAddress"),
            ],
            kind: .Ledger(
                TonSwift.PublicKey(data: Data(repeating: 1, count: 32)),
                .v4R2,
                Wallet.LedgerDevice(deviceId: UUID().uuidString, deviceModel: "Flex", accountIndex: 0)
            )
        )

        XCTAssertEqual(resolve(asset: makeAsset(assetId: "ton/mainnet/coin"), wallet: wallet), .tonCoin)
        XCTAssertEqual(resolve(asset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"), wallet: wallet), .tonJetton(master: "0:jetton-master"))
        XCTAssertEqual(resolve(asset: makeAsset(assetId: "eth/mainnet/coin"), wallet: wallet, relayedEVMChains: [.eth]), .chainKit)
        XCTAssertEqual(resolve(asset: makeAsset(assetId: "sol/mainnet/coin"), wallet: wallet, relayedEVMChains: [.sol]), .chainKit)
        XCTAssertEqual(
            resolve(asset: makeAsset(assetId: "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)"), wallet: wallet),
            .tronUSDT(tronAddress: "TLedgerTronAddress")
        )
        XCTAssertEqual(resolve(asset: makeAsset(assetId: "tron/mainnet/coin"), wallet: wallet), .chainKit)
    }

    func testNonUSDTTRC20KeepsChainKitEngine() {
        let wallet = makeWallet(addresses: [
            .init(chain: .tron, address: "TMultichainTronAddress"),
        ])

        let engine = resolve(
            asset: makeAsset(assetId: "tron/mainnet/trc20/TNonUSDTContract"),
            wallet: wallet
        )

        XCTAssertEqual(engine, .chainKit)
    }
}

private extension MultichainFeeEngineResolverTests {
    func resolve(
        asset: MultichainAsset,
        wallet: Wallet,
        relayedEVMChains: Set<MultichainChain> = [.eth, .arb, .base]
    ) -> MultichainFeeEngineResolver.Engine {
        MultichainFeeEngineResolver(relayedEVMChains: { [] })
            .resolve(asset: asset, wallet: wallet, relayedEVMChains: relayedEVMChains)
    }

    func makeWallet(
        addresses: [MultichainWalletAddress],
        kind: WalletKind = .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
    ) -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(
                network: .mainnet,
                kind: kind
            ),
            metaData: .init(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init(),
            multichain: .multichain(
                .init(walletId: "multichain-wallet-id", addresses: addresses)
            )
        )
    }

    func makeAsset(assetId: String) -> MultichainAsset {
        MultichainAsset(
            asset: .init(
                assetId: assetId,
                name: "Test asset",
                symbol: "TEST",
                decimals: 6,
                image: ""
            ),
            price: .init(prices: [:], diff24h: [:], diff7d: [:]),
            balance: 0
        )
    }
}
