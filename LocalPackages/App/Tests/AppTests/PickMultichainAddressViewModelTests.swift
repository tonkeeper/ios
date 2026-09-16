@testable import App
import KeeperCore
import XCTest

@MainActor
final class PickMultichainAddressViewModelTests: XCTestCase {
    func test_duplicateChainAddressesHaveVersionTags() {
        let tonV4Address = MultichainWalletAddress(
            chain: .ton,
            address: "ton-v4-address",
            type: .tonV4R2
        )
        let tonV5Address = MultichainWalletAddress(
            chain: .ton,
            address: "ton-v5-address",
            type: .tonV5R1
        )
        let ethAddress = MultichainWalletAddress(
            chain: .eth,
            address: "eth-address"
        )

        let viewModel = PickMultichainAddressViewModelImplementation(
            addresses: [tonV4Address, tonV5Address, ethAddress]
        )

        XCTAssertEqual(viewModel.items.map(\.address), [tonV4Address, tonV5Address, ethAddress])
        XCTAssertEqual(viewModel.items[0].versionTag, MultichainWalletAddressType.tonV4R2.rawValue)
        XCTAssertEqual(viewModel.items[1].versionTag, MultichainWalletAddressType.tonV5R1.rawValue)
        XCTAssertNil(viewModel.items[2].versionTag)
    }

    func test_singleChainAddressHasNoVersionTag() {
        let tonAddress = MultichainWalletAddress(
            chain: .ton,
            address: "ton-v4-address",
            type: .tonV4R2
        )

        let viewModel = PickMultichainAddressViewModelImplementation(
            addresses: [tonAddress]
        )

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertNil(viewModel.items.first?.versionTag)
    }

    func test_receiveAddressPreviewWalletAddressPreservesType() {
        let walletAddress = MultichainWalletAddress(
            chain: .ton,
            address: "ton-v5-address",
            type: .tonV5R1
        )

        let preview = ReceiveAddressPreview(address: walletAddress)

        XCTAssertEqual(preview.type, .tonV5R1)
        XCTAssertEqual(preview.walletAddress, walletAddress)
    }
}
