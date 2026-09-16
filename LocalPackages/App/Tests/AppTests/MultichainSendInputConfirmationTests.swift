@testable import App
import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

final class MultichainSendInputConfirmationTests: XCTestCase {
    private let tronAddress = "TKoUnkRBggFPbbsPnXqdnbjfVzRhDfnhoc"

    func test_isReadyForConfirmation_matchingChainAndPositiveAmount() {
        let input = makeInput(chain: .eth, amount: 100)

        XCTAssertTrue(
            input.isReadyForConfirmation(
                recipient: MultichainRecipient(chain: .eth, address: "0xrecipient"),
                wallet: makeWallet()
            )
        )
    }

    func test_isReadyForConfirmation_zeroAmount() {
        let input = makeInput(chain: .eth, amount: 0)

        XCTAssertFalse(
            input.isReadyForConfirmation(
                recipient: MultichainRecipient(chain: .eth, address: "0xrecipient"),
                wallet: makeWallet()
            )
        )
    }

    func test_isReadyForConfirmation_recipientOnAnotherChain() {
        let input = makeInput(chain: .eth, amount: 100)

        XCTAssertFalse(
            input.isReadyForConfirmation(
                recipient: MultichainRecipient(chain: .base, address: "0xrecipient"),
                wallet: makeWallet()
            )
        )
    }

    func test_isReadyForConfirmation_withoutRecipient() {
        let input = makeInput(chain: .eth, amount: 100)

        XCTAssertFalse(input.isReadyForConfirmation(recipient: nil, wallet: makeWallet()))
    }

    func test_isReadyForConfirmation_amountAboveBalance() {
        let input = makeInput(chain: .eth, amount: 100, balance: 99)

        XCTAssertFalse(
            input.isReadyForConfirmation(
                recipient: MultichainRecipient(chain: .eth, address: "0xrecipient"),
                wallet: makeWallet()
            )
        )
    }

    func test_isReadyForConfirmation_amountEqualToBalance() {
        let input = makeInput(chain: .eth, amount: 100, balance: 100)

        XCTAssertTrue(
            input.isReadyForConfirmation(
                recipient: MultichainRecipient(chain: .eth, address: "0xrecipient"),
                wallet: makeWallet()
            )
        )
    }

    /// The form rejects this recipient outright, so a pinned deeplink must not carry it past the
    /// form and onto confirmation, where the rule is never applied.
    func test_isReadyForConfirmation_nativeTrxToOwnAddress() {
        let input = makeInput(chain: .tron, amount: 100, assetId: "tron/mainnet/coin")

        XCTAssertFalse(
            input.isReadyForConfirmation(
                recipient: MultichainRecipient(chain: .tron, address: tronAddress),
                wallet: makeWallet()
            )
        )
    }

    func test_isReadyForConfirmation_nativeTrxToAnotherAddress() {
        let input = makeInput(chain: .tron, amount: 100, assetId: "tron/mainnet/coin")

        XCTAssertTrue(
            input.isReadyForConfirmation(
                recipient: MultichainRecipient(chain: .tron, address: "TU4vEruvZwLLkSfV9bNw12EJTPvNr7Pvaa"),
                wallet: makeWallet()
            )
        )
    }

    /// Only the native coin is refused: a TRC-20 transfer to the wallet's own address is allowed.
    func test_isReadyForConfirmation_tronTokenToOwnAddress() {
        let input = makeInput(
            chain: .tron,
            amount: 100,
            assetId: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
        )

        XCTAssertTrue(
            input.isReadyForConfirmation(
                recipient: MultichainRecipient(chain: .tron, address: tronAddress),
                wallet: makeWallet()
            )
        )
    }

    func test_isReadyForConfirmation_assetWithoutChain() {
        let input = makeInput(chain: nil, amount: 100)

        XCTAssertFalse(
            input.isReadyForConfirmation(
                recipient: MultichainRecipient(chain: .eth, address: "0xrecipient"),
                wallet: makeWallet()
            )
        )
    }
}

private extension MultichainSendInputConfirmationTests {
    func makeInput(
        chain: MultichainChain?,
        amount: BigUInt,
        balance: BigUInt = 1000,
        assetId: String = "asset"
    ) -> MultichainSendInput {
        MultichainSendInput(
            item: MultichainSendItem(
                asset: MultichainAsset(
                    asset: MultichainAssetDetails(
                        assetId: assetId,
                        chain: chain,
                        name: "Ether",
                        symbol: "ETH",
                        decimals: 18,
                        image: ""
                    ),
                    price: MultichainAssetPrice(
                        prices: [:],
                        diff24h: [:],
                        diff7d: [:],
                        diff30d: [:]
                    ),
                    balance: balance,
                    marketCap: [:]
                ),
                amount: amount
            )
        )
    }

    func makeWallet() -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(PublicKey(data: Data(repeating: 0x01, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "wallet",
                    addresses: [
                        MultichainWalletAddress(chain: .tron, address: tronAddress),
                    ]
                )
            )
        )
    }
}
