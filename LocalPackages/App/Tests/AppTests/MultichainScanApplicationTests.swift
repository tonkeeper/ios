@testable import App
@testable import KeeperCore
import XCTest

final class MultichainScanApplicationTests: XCTestCase {
    private let usdtOnEth = "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"

    /// The regression this type exists for: a link naming chain and token is a later, explicit
    /// instruction, so it overrides a manual token pick instead of leaving the form on a recipient
    /// whose chain cannot match the selected asset.
    func test_pinnedAssetSwitchesEvenWhenAutomaticChainSwitchIsDisallowed() {
        let application = MultichainScanApplication(
            scannedAssetId: usdtOnEth,
            selectedAssetId: "ton/mainnet/coin",
            recipientChain: .eth,
            selectedChain: .ton,
            allowsAutomaticChainSwitch: false
        )

        XCTAssertEqual(application, .switchAsset(assetId: usdtOnEth))
    }

    func test_pinnedAssetMatchingSelectionAppliesInPlace() {
        let application = MultichainScanApplication(
            scannedAssetId: usdtOnEth,
            selectedAssetId: usdtOnEth,
            recipientChain: .eth,
            selectedChain: .eth,
            allowsAutomaticChainSwitch: false
        )

        XCTAssertEqual(application, .applyInPlace)
    }

    func test_pinnedAssetSwitchesWhenNothingIsSelectedYet() {
        let application = MultichainScanApplication(
            scannedAssetId: usdtOnEth,
            selectedAssetId: nil,
            recipientChain: .eth,
            selectedChain: nil,
            allowsAutomaticChainSwitch: true
        )

        XCTAssertEqual(application, .switchAsset(assetId: usdtOnEth))
    }

    func test_inferredChainSwitchesToTheChainDefaultAsset() {
        let application = MultichainScanApplication(
            scannedAssetId: nil,
            selectedAssetId: "ton/mainnet/coin",
            recipientChain: .tron,
            selectedChain: .ton,
            allowsAutomaticChainSwitch: true
        )

        XCTAssertEqual(application, .switchAsset(assetId: MultichainChain.tron.defaultSendAssetId))
    }

    /// A chain inferred from an address valid on several chains must not override a manual pick.
    func test_inferredChainIsIgnoredWhenAutomaticChainSwitchIsDisallowed() {
        let application = MultichainScanApplication(
            scannedAssetId: nil,
            selectedAssetId: "ton/mainnet/coin",
            recipientChain: .eth,
            selectedChain: .ton,
            allowsAutomaticChainSwitch: false
        )

        XCTAssertEqual(application, .applyInPlace)
    }

    func test_inferredChainMatchingSelectionAppliesInPlace() {
        let application = MultichainScanApplication(
            scannedAssetId: nil,
            selectedAssetId: "eth/mainnet/coin",
            recipientChain: .eth,
            selectedChain: .eth,
            allowsAutomaticChainSwitch: true
        )

        XCTAssertEqual(application, .applyInPlace)
    }
}
