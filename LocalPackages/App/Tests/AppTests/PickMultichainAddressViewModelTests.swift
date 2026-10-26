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
            addresses: [tonV4Address, tonV5Address, ethAddress],
            newChainBadgeService: NewChainBadgeServiceStub(newChains: [])
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
            addresses: [tonAddress],
            newChainBadgeService: NewChainBadgeServiceStub(newChains: [])
        )

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertNil(viewModel.items.first?.versionTag)
    }

    func test_newBadgeFollowsService() {
        let viewModel = PickMultichainAddressViewModelImplementation(
            addresses: [
                MultichainWalletAddress(chain: .ton, address: "ton-address", type: .tonV5R1),
                MultichainWalletAddress(chain: .sol, address: "sol-address"),
            ],
            newChainBadgeService: NewChainBadgeServiceStub(newChains: [.sol])
        )

        XCTAssertEqual(viewModel.items.map(\.isNew), [false, true])
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

private struct NewChainBadgeServiceStub: NewChainBadgeService {
    let newChains: Set<MultichainChain>

    func shouldShowBadge(for chain: MultichainChain) -> Bool {
        newChains.contains(chain)
    }
}
