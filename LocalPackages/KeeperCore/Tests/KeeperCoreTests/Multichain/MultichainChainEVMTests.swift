@testable import KeeperCore
import XCTest

final class MultichainChainEVMTests: XCTestCase {
    func test_eip155ChainIds() {
        XCTAssertEqual(MultichainChain.eth.eip155ChainId, 1)
        XCTAssertEqual(MultichainChain.base.eip155ChainId, 8453)
        XCTAssertEqual(MultichainChain.arb.eip155ChainId, 42161)
        XCTAssertEqual(MultichainChain.bsc.eip155ChainId, 56)
        XCTAssertNil(MultichainChain.ton.eip155ChainId)
        XCTAssertNil(MultichainChain.btc.eip155ChainId)
        XCTAssertNil(MultichainChain.tron.eip155ChainId)
    }

    func test_initFromEip155ChainId() {
        XCTAssertEqual(MultichainChain(eip155ChainId: 1), .eth)
        XCTAssertEqual(MultichainChain(eip155ChainId: 8453), .base)
        XCTAssertEqual(MultichainChain(eip155ChainId: 42161), .arb)
        XCTAssertEqual(MultichainChain(eip155ChainId: 56), .bsc)
        XCTAssertNil(MultichainChain(eip155ChainId: 137))
        XCTAssertNil(MultichainChain(eip155ChainId: 0))
    }

    func test_isEVM() {
        XCTAssertEqual(
            MultichainChain.allCases.filter(\.isEVM),
            [.eth, .base, .arb, .bsc]
        )
    }

    func test_walletConnectChainReusesTheSameChainIds() {
        for chain in WalletConnectChain.allCases {
            XCTAssertEqual(
                chain.eip155ChainId,
                chain.multichainChain.eip155ChainId.map(Int32.init)
            )
        }
    }

    func test_bnbIsAcceptedAsBscAlias() {
        XCTAssertEqual(MultichainChain(assetIdChain: "bnb"), .bsc)
        XCTAssertEqual(MultichainChain(assetIdChain: "BNB"), .bsc)
        XCTAssertEqual(MultichainChain(assetIdChain: "bsc"), .bsc)
    }
}
