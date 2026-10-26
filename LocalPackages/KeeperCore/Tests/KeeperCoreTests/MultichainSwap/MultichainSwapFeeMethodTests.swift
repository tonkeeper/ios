import BigInt
@testable import KeeperCore
import XCTest

final class MultichainSwapFeeMethodTests: XCTestCase {
    private let usdt = MultichainAssetDetails(assetId: "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7", name: "Tether", symbol: "USDT", decimals: 6, image: "")

    func test_everyMethodSurvivesItsId() {
        let methods: [MultichainSwapFeeMethod] = [.native, .battery, .gram, .token(assetId: usdt.assetId)]

        XCTAssertEqual(methods.map { MultichainSwapFeeMethod(id: $0.id) }, methods)
        XCTAssertEqual(methods.map(\.id), ["native", "battery", "gram", "token:\(usdt.assetId)"])
        XCTAssertNil(MultichainSwapFeeMethod(id: "jetton"))
    }

    func test_aTokenPaidFeeIsRelayedAndRefilledByADeposit() {
        let option = MultichainSwapFeeOption(cost: .token(usdt, amount: 115_304, isInsufficient: true))

        XCTAssertEqual(option.method, .token(assetId: usdt.assetId))
        XCTAssertTrue(option.method.isRelayed)
        XCTAssertFalse(option.method.isBattery)
        XCTAssertTrue(option.isInsufficient)
        XCTAssertEqual(option.depositAsset, usdt)
        XCTAssertEqual(option.relayedFee, .token(assetId: usdt.assetId, amount: 115_304))
    }
}
