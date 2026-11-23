import ChainKit
@testable import KeeperCore
import XCTest

final class SwapApprovalTransactionResolverTests: XCTestCase {
    private static let token = "0x4444444444444444444444444444444444444444"
    private static let router = "0x2222222222222222222222222222222222222222"

    private lazy var resolver = SwapApprovalTransactionResolver(
        client: CryptoKitClient(
            netModule: ModuleNetModule(
                netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
            )
        )
    )

    func test_keepsTheProvidersApprovalWhateverItAllows() throws {
        let swap = try makeSwap()
        let fee = makeFee(price: 10)
        for allowance in [String(repeating: "0", count: 62) + "2a", String(repeating: "f", count: 64)] {
            let data = Self.approveData(allowance: allowance)

            let approval = try XCTUnwrap(
                resolver.resolveApprovalTransaction(
                    mainTransactions: [swap],
                    approvalData: data,
                    approvalFee: fee,
                    mainFee: makeFee(price: 20)
                )
            )

            XCTAssertEqual(approval.transaction.data, data)
            XCTAssertEqual(approval.transaction.contract.display, Self.token)
            XCTAssertEqual(approval.transaction.amount.description, "0")
            XCTAssertTrue((approval.fee as? FeeGas) === fee)
        }
    }

    func test_approvalTheAggregatorDidNotPricePaysTheMainFeeScaledByOneAndAHalf() throws {
        let fee = try XCTUnwrap(unpricedApprovalFee(mainFee: makeFee(price: 10)) as? FeeGas)

        XCTAssertEqual(fee.limit.description, "2")
        XCTAssertEqual(fee.price.description, "15")
        XCTAssertEqual(fee.amount.description, "30")
    }

    func test_approvalTheAggregatorDidNotPriceScalesAnEip1559MainFeeByOneAndAHalf() throws {
        let mainFee = FeeEip1559(
            asset: ChainEthereumMainnet.shared.toAsset(),
            limit: Self.bignum(2),
            networkPrice: Self.bignum(4),
            maxPrice: Self.bignum(10),
            minerPrice: Self.bignum(2),
            amount: Self.bignum(20)
        )

        let fee = try XCTUnwrap(unpricedApprovalFee(mainFee: mainFee) as? FeeEip1559)

        XCTAssertEqual(fee.limit.description, "2")
        XCTAssertEqual(fee.networkPrice.description, "4")
        XCTAssertEqual(fee.maxPrice.description, "15")
        XCTAssertEqual(fee.minerPrice.description, "3")
        XCTAssertEqual(fee.amount.description, "30")
    }
}

private extension SwapApprovalTransactionResolverTests {
    /// `approve(router, allowance)`, with the allowance as 64 hex digits.
    static func approveData(allowance: String) -> String {
        "0x095ea7b3" + String(repeating: "0", count: 24) + router.dropFirst(2) + allowance
    }

    static func bignum(_ value: Int32) -> BignumBigInteger {
        BignumBigInteger.Companion.shared.fromInt(int: value)
    }

    func unpricedApprovalFee(mainFee: any Fee) throws -> any Fee {
        try XCTUnwrap(
            resolver.resolveApprovalTransaction(
                mainTransactions: [makeSwap()],
                approvalData: Self.approveData(allowance: String(repeating: "0", count: 62) + "2a"),
                approvalFee: nil,
                mainFee: mainFee
            )
        ).fee
    }

    func makeFee(price: Int32) -> FeeGas {
        let limit = Self.bignum(2)
        let price = Self.bignum(price)
        return FeeGas(
            asset: ChainEthereumMainnet.shared.toAsset(),
            limit: limit,
            price: price,
            amount: limit.multiply(other: price)
        )
    }

    func makeSwap() throws -> TransactionSwap {
        let chain = ChainEthereumMainnet.shared
        let address = try XCTUnwrap(ChainKit.Address.Companion.shared.from(
            value: "0x1111111111111111111111111111111111111111",
            chain: chain,
            type: .default_
        ))
        let router = try XCTUnwrap(ChainKit.Address.Companion.shared.from(value: Self.router, chain: chain, type: .default_))
        let token = try XCTUnwrap(AssetCompanion.shared.fromString(
            assetId: "eth/mainnet/erc20/\(Self.token)",
            name: "Token",
            symbol: "TKN",
            decimals: 6
        ))
        return TransactionSwap(
            account: ChainKit.Account(address: address, asset: token, derivation: DerivationDefaultPath.shared, publicKey: nil),
            amount: Self.bignum(7),
            isMax: false,
            destination: ChainKit.Account(
                address: address,
                asset: chain.toAsset(),
                derivation: DerivationDefaultPath.shared,
                publicKey: nil
            ),
            to: router,
            data: "0xabcdef",
            initData: nil,
            memo: nil
        )
    }
}
