import ChainKit
@testable import KeeperCore
import XCTest

final class MultichainChainEVMTests: XCTestCase {
    func test_eip155ChainIds() {
        XCTAssertEqual(MultichainChain.eth.eip155ChainId, 1)
        XCTAssertEqual(MultichainChain.base.eip155ChainId, 8453)
        XCTAssertEqual(MultichainChain.arb.eip155ChainId, 42161)
        XCTAssertEqual(MultichainChain.bsc.eip155ChainId, 56)
        XCTAssertEqual(MultichainChain.polygon.eip155ChainId, 137)
        XCTAssertEqual(MultichainChain.avax.eip155ChainId, 43114)
        XCTAssertEqual(MultichainChain.robinhood.eip155ChainId, 4663)
        XCTAssertNil(MultichainChain.ton.eip155ChainId)
        XCTAssertNil(MultichainChain.btc.eip155ChainId)
        XCTAssertNil(MultichainChain.tron.eip155ChainId)
        XCTAssertNil(MultichainChain.sol.eip155ChainId)
    }

    func test_initFromEip155ChainId() {
        XCTAssertEqual(MultichainChain(eip155ChainId: 1), .eth)
        XCTAssertEqual(MultichainChain(eip155ChainId: 8453), .base)
        XCTAssertEqual(MultichainChain(eip155ChainId: 42161), .arb)
        XCTAssertEqual(MultichainChain(eip155ChainId: 56), .bsc)
        XCTAssertEqual(MultichainChain(eip155ChainId: 137), .polygon)
        XCTAssertEqual(MultichainChain(eip155ChainId: 43114), .avax)
        XCTAssertEqual(MultichainChain(eip155ChainId: 4663), .robinhood)
        XCTAssertNil(MultichainChain(eip155ChainId: 10))
        XCTAssertNil(MultichainChain(eip155ChainId: 0))
    }

    func test_eip155ChainIdsMatchChainKit() {
        for chain in MultichainChain.allCases {
            XCTAssertEqual(
                chain.eip155ChainId.map(Int64.init),
                (chain.asChainKitChain as? ChainEvm)?.number,
                "\(chain)"
            )
        }
    }

    func test_isEVM() {
        XCTAssertEqual(
            MultichainChain.allCases.filter(\.isEVM),
            [.eth, .base, .arb, .bsc, .polygon, .avax, .robinhood]
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
