@testable import App
import BigInt
@testable import KeeperCore
import TronSwift
import XCTest

final class MultichainSendSeedTests: XCTestCase {
    func test_multichainSeed_mapsTonCoinToCoinAssetId() {
        let seed = SendInput.direct(item: .ton(.token(.ton, amount: 100))).multichainSeed()

        XCTAssertEqual(seed?.assetId, "ton/mainnet/coin")
        XCTAssertEqual(seed?.amount, 100)
    }

    func test_multichainSeed_mapsTronUsdtToTrc20AssetId() {
        let seed = SendInput.direct(item: .tron(.usdt(amount: 5))).multichainSeed()

        XCTAssertEqual(seed?.assetId, "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)")
        XCTAssertEqual(seed?.amount, 5)
    }
}
