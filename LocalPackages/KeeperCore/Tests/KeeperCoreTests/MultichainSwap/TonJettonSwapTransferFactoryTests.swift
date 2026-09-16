import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

final class TonJettonSwapTransferFactoryTests: XCTestCase {
    func test_makeTransferBuildsJettonDepositFromSourceMaster() throws {
        let master = try Address.parse(masterAddress)
        let walletAddress = try Address.parse(jettonWalletAddress)
        let recipientAddress = try Address.parse(recipient)
        let item = makeJettonItem(master: master, walletAddress: walletAddress)

        let transfer = try XCTUnwrap(
            TonJettonSwapTransferFactory.makeTransfer(
                sourceAsset: makeAsset(master: masterAddress),
                deposit: TonJettonSwapDeposit(recipient: recipient, amount: 100_000_000),
                jettons: [makeBalance(item: item)],
                transferAmount: 80_000_000
            )
        )

        guard case let .jetton(resolvedItem, transferAmount, amount, resolvedRecipient, comment) = transfer else {
            return XCTFail("Expected a jetton transfer")
        }
        XCTAssertEqual(resolvedItem, item)
        XCTAssertEqual(transferAmount, 80_000_000)
        XCTAssertEqual(amount, 100_000_000)
        XCTAssertEqual(resolvedRecipient.recipientAddress.address, recipientAddress)
        XCTAssertNil(comment)
    }

    func test_makeTransferFailsWithoutMatchingJettonWallet() throws {
        let master = try Address.parse(masterAddress)
        let differentMaster = try Address.parse("0:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        let walletAddress = try Address.parse(jettonWalletAddress)

        XCTAssertNil(
            TonJettonSwapTransferFactory.makeTransfer(
                sourceAsset: makeAsset(master: masterAddress),
                deposit: TonJettonSwapDeposit(recipient: recipient, amount: 1),
                jettons: [makeBalance(item: makeJettonItem(master: differentMaster, walletAddress: walletAddress))],
                transferAmount: 80_000_000
            )
        )
        XCTAssertNil(
            TonJettonSwapTransferFactory.makeTransfer(
                sourceAsset: makeAsset(master: masterAddress),
                deposit: TonJettonSwapDeposit(recipient: recipient, amount: 1),
                jettons: [makeBalance(item: makeJettonItem(master: master, walletAddress: nil))],
                transferAmount: 80_000_000
            )
        )
    }

    func test_makeTransferFailsForMalformedAssetAndRecipient() throws {
        let master = try Address.parse(masterAddress)
        let walletAddress = try Address.parse(jettonWalletAddress)
        let balance = makeBalance(item: makeJettonItem(master: master, walletAddress: walletAddress))

        XCTAssertNil(
            TonJettonSwapTransferFactory.makeTransfer(
                sourceAsset: makeAsset(master: "not-an-address"),
                deposit: TonJettonSwapDeposit(recipient: recipient, amount: 1),
                jettons: [balance],
                transferAmount: 80_000_000
            )
        )
        XCTAssertNil(
            TonJettonSwapTransferFactory.makeTransfer(
                sourceAsset: makeAsset(master: masterAddress),
                deposit: TonJettonSwapDeposit(recipient: "not-an-address", amount: 1),
                jettons: [balance],
                transferAmount: 80_000_000
            )
        )
    }

    func test_requiredTransferAmountAddsFeeButNotRefund() {
        XCTAssertEqual(
            TonJettonSwapTransferFactory.requiredTransferAmount(
                minimum: 80_000_000,
                emulationAmount: .fee(5_000_000)
            ),
            85_000_000
        )
        XCTAssertEqual(
            TonJettonSwapTransferFactory.requiredTransferAmount(
                minimum: 80_000_000,
                emulationAmount: .refund(5_000_000)
            ),
            80_000_000
        )
    }
}

private extension TonJettonSwapTransferFactoryTests {
    var masterAddress: String {
        "0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"
    }

    var jettonWalletAddress: String {
        "0:0000000000000000000000000000000000000000000000000000000000000001"
    }

    var recipient: String {
        "0:0000000000000000000000000000000000000000000000000000000000000002"
    }

    func makeAsset(master: String) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: "ton/mainnet/jetton/\(master)",
                name: "USDT",
                symbol: "USD₮",
                decimals: 6,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:], diff30d: [:]),
            balance: 0
        )
    }

    func makeJettonItem(master: Address, walletAddress: Address?) -> JettonItem {
        JettonItem(
            jettonInfo: JettonInfo(
                isTransferable: true,
                hasCustomPayload: false,
                address: master,
                fractionDigits: 6,
                name: "USDT",
                symbol: "USD₮",
                verification: .whitelist,
                imageURL: nil
            ),
            walletAddress: walletAddress
        )
    }

    func makeBalance(item: JettonItem) -> JettonBalance {
        JettonBalance(item: item, quantity: 1_000_000_000, rates: [:])
    }
}
