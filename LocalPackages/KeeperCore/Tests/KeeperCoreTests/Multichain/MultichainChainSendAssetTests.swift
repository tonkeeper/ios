@testable import KeeperCore
import TronSwift
import XCTest

final class MultichainChainSendAssetTests: XCTestCase {
    func test_defaultSendAssetId_tronIsUsdtTrc20() {
        XCTAssertEqual(
            MultichainChain.tron.defaultSendAssetId,
            "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)"
        )
    }

    func test_defaultSendAssetId_nonTronIsNativeCoin() {
        XCTAssertEqual(MultichainChain.ton.defaultSendAssetId, "ton/mainnet/coin")
        XCTAssertEqual(MultichainChain.eth.defaultSendAssetId, "eth/mainnet/coin")
        XCTAssertEqual(MultichainChain.base.defaultSendAssetId, "base/mainnet/coin")
        XCTAssertEqual(MultichainChain.btc.defaultSendAssetId, "btc/mainnet/coin")
        XCTAssertEqual(MultichainChain.arb.defaultSendAssetId, "arb/mainnet/coin")
        XCTAssertEqual(MultichainChain.bsc.defaultSendAssetId, "bsc/mainnet/coin")
    }
}
