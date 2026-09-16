import ChainKit
@testable import KeeperCore
import XCTest

final class WalletConnectRequestFeeFactoryTests: XCTestCase {
    func testGasOnlyEIP1559ReturnsNilForChainKitEstimation() throws {
        let fee = try WalletConnectRequestFeeFactory.requestFee(
            payload: transaction(gas: "0x5208"),
            chain: .eth
        )

        XCTAssertNil(fee)
    }

    func testValidEIP1559FieldsCreateRequestFee() throws {
        let fee = try WalletConnectRequestFeeFactory.requestFee(
            payload: transaction(
                gas: "0x5208",
                maxFeePerGas: "0x64",
                maxPriorityFeePerGas: "0x2"
            ),
            chain: .eth
        )

        let eip1559Fee = try XCTUnwrap(fee as? FeeEip1559)
        XCTAssertEqual(eip1559Fee.limit.intValue(exactRequired: true), 21000)
        XCTAssertEqual(eip1559Fee.networkPrice.intValue(exactRequired: true), 0)
        XCTAssertEqual(eip1559Fee.maxPrice.intValue(exactRequired: true), 100)
        XCTAssertEqual(eip1559Fee.minerPrice.intValue(exactRequired: true), 2)
        XCTAssertEqual(eip1559Fee.amount.intValue(exactRequired: true), 2_100_000)
    }

    func testValidLegacyGasPriceCreatesRequestFee() throws {
        let fee = try WalletConnectRequestFeeFactory.requestFee(
            payload: transaction(
                gas: "0x5208",
                gasPrice: "0x32"
            ),
            chain: .bsc
        )

        let gasFee = try XCTUnwrap(fee as? FeeGas)
        XCTAssertEqual(gasFee.limit.intValue(exactRequired: true), 21000)
        XCTAssertEqual(gasFee.price.intValue(exactRequired: true), 50)
        XCTAssertEqual(gasFee.amount.intValue(exactRequired: true), 1_050_000)
    }

    func testGasPriceOnlyOnEIP1559ChainCreatesLegacyRequestFee() throws {
        let fee = try WalletConnectRequestFeeFactory.requestFee(
            payload: transaction(
                gas: "0x5208",
                gasPrice: "0x32"
            ),
            chain: .arb
        )

        let gasFee = try XCTUnwrap(fee as? FeeGas)
        XCTAssertEqual(gasFee.limit.intValue(exactRequired: true), 21000)
        XCTAssertEqual(gasFee.price.intValue(exactRequired: true), 50)
        XCTAssertEqual(gasFee.amount.intValue(exactRequired: true), 1_050_000)
    }

    func testZeroFeeFieldThrowsInsteadOfFallingBackToEstimation() throws {
        XCTAssertThrowsError(
            try WalletConnectRequestFeeFactory.requestFee(
                payload: transaction(
                    gas: "0x5208",
                    maxFeePerGas: "0x0",
                    maxPriorityFeePerGas: "0x2"
                ),
                chain: .eth
            )
        ) { error in
            XCTAssertEqual(
                error as? WalletConnectSigningError,
                .invalidTransaction(reason: "WalletConnect transaction maxFeePerGas must be greater than zero")
            )
        }
    }

    func testZeroGasThrowsInsteadOfFallingBackToEstimation() throws {
        XCTAssertThrowsError(
            try WalletConnectRequestFeeFactory.requestFee(
                payload: transaction(gas: "0x0"),
                chain: .eth
            )
        ) { error in
            XCTAssertEqual(
                error as? WalletConnectSigningError,
                .invalidTransaction(reason: "WalletConnect transaction gas must be greater than zero")
            )
        }
    }

    func testInvalidFeeFieldThrowsInsteadOfFallingBackToEstimation() throws {
        XCTAssertThrowsError(
            try WalletConnectRequestFeeFactory.requestFee(
                payload: transaction(
                    gas: "0x5208",
                    gasPrice: "0x"
                ),
                chain: .bsc
            )
        ) { error in
            XCTAssertEqual(
                error as? WalletConnectSigningError,
                .invalidTransaction(reason: "invalid EVM quantity gasPrice: 0x")
            )
        }
    }

    func testInvalidFeeFieldWithoutGasThrowsInsteadOfFallingBackToEstimation() throws {
        XCTAssertThrowsError(
            try WalletConnectRequestFeeFactory.requestFee(
                payload: transaction(gasPrice: "0x"),
                chain: .bsc
            )
        ) { error in
            XCTAssertEqual(
                error as? WalletConnectSigningError,
                .invalidTransaction(reason: "invalid EVM quantity gasPrice: 0x")
            )
        }
    }

    func testPartialEIP1559FieldsThrowInsteadOfCreatingZeroFee() throws {
        XCTAssertThrowsError(
            try WalletConnectRequestFeeFactory.requestFee(
                payload: transaction(
                    gas: "0x5208",
                    maxFeePerGas: "0x64"
                ),
                chain: .eth
            )
        ) { error in
            XCTAssertEqual(
                error as? WalletConnectSigningError,
                .invalidTransaction(reason: "WalletConnect transaction EIP-1559 fee requires maxFeePerGas and maxPriorityFeePerGas")
            )
        }
    }
}

private extension WalletConnectRequestFeeFactoryTests {
    func transaction(
        gas: String? = nil,
        gasPrice: String? = nil,
        maxFeePerGas: String? = nil,
        maxPriorityFeePerGas: String? = nil
    ) -> WalletConnectEVMTransaction {
        WalletConnectEVMTransaction(
            from: nil,
            to: "0x0000000000000000000000000000000000000000",
            data: "0x",
            value: "0x0",
            nonce: nil,
            gas: gas,
            gasPrice: gasPrice,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas
        )
    }
}
