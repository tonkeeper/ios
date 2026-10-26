@testable import KeeperCore
import TKCore
import TonSwift
import XCTest

final class EarnTransactionSentTests: XCTestCase {
    func test_contractCallIsACallInTheChainsCoin() throws {
        let event = try XCTUnwrap(
            TransactionSent(
                wallet: wallet,
                evmTransaction: transaction(data: "0x6e553f65", value: "0x0"),
                chain: .eth,
                origin: TransactionOrigin(initiatedBy: .evmInjected, dappUrl: "vaults.fyi")
            )
        )

        XCTAssertEqual(event.category, .call)
        XCTAssertEqual(event.categoryDetail, .unknown)
        XCTAssertEqual(event.asset, "eth/mainnet/coin")
        XCTAssertEqual(event.amount, 0)
        XCTAssertEqual(event.feeAsset, .coin)
        XCTAssertEqual(event.walletInterface, .eoa)
        XCTAssertEqual(event.initiatedBy, .evmInjected)
        XCTAssertEqual(event.dappUrl, "vaults.fyi")
    }

    func test_valueWithoutCalldataIsACoinTransfer() throws {
        let event = try XCTUnwrap(
            TransactionSent(
                wallet: wallet,
                evmTransaction: transaction(data: "0x", value: "0xde0b6b3a7640000"),
                chain: .bnb,
                origin: TransactionOrigin(initiatedBy: .evmInjected, dappUrl: "vaults.fyi")
            )
        )

        XCTAssertEqual(event.category, .transfer)
        XCTAssertEqual(event.categoryDetail, .coin)
        XCTAssertEqual(event.asset, "bnb/mainnet/coin")
        XCTAssertEqual(event.amount, 1)
    }
}

private extension EarnTransactionSentTests {
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
                        MultichainWalletAddress(chain: .eth, address: "0x1111111111111111111111111111111111111111"),
                    ]
                )
            )
        )
    }

    func transaction(data: String, value: String) -> WalletConnectEVMTransaction {
        WalletConnectEVMTransaction(
            from: "0x1111111111111111111111111111111111111111",
            to: "0x2222222222222222222222222222222222222222",
            data: data,
            value: value,
            nonce: nil,
            gas: nil,
            gasPrice: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil
        )
    }
}
