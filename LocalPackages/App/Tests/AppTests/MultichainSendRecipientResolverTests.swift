@testable import App
@testable import KeeperCore
import XCTest

final class MultichainSendRecipientResolverTests: XCTestCase {
    private let evmAddress = "0x000000000000000000000000000000000000dead"
    private let bitcoinAddress = "1BoatSLRHtKNngkdXEeobR76b53LETtpyT"
    private let evmChains: [MultichainChain] = [.eth, .base, .arb, .bsc]
    private let tonMainnetAddress = "UQBcmqkZxhc81WNeFFzq9ZX6qBlP28B-MuYeSxpS_-YMIDNl"
    private let tonTestnetAddress = "0QAfY673Jt4NZZoy1pNjzv4da419kXisdhsJRx6F6_qwOopM"

    // MARK: - resolveDeeplink

    func test_deeplink_primaryChainInWallet_seedsPrimaryAndOffersWalletChains() {
        let resolution = MultichainSendRecipientResolver().resolveDeeplink(
            candidates: evmCandidates,
            walletChains: [.ton, .base, .eth],
            network: .mainnet
        )

        XCTAssertEqual(
            resolution,
            .send(
                recipient: MultichainRecipient(chain: .eth, address: evmAddress),
                availableChains: [.eth, .base]
            )
        )
    }

    func test_deeplink_noCandidateInWallet_isUnsupported() {
        let resolution = MultichainSendRecipientResolver().resolveDeeplink(
            candidates: MultichainRecipientCandidates(address: bitcoinAddress, chains: [.btc]),
            walletChains: [.ton, .eth],
            network: .mainnet
        )

        XCTAssertEqual(resolution, .unsupported)
    }

    func test_deeplink_offersEveryWalletChainAmongCandidates() {
        let resolution = MultichainSendRecipientResolver().resolveDeeplink(
            candidates: evmCandidates,
            walletChains: [.ton, .eth, .base, .bsc],
            network: .mainnet
        )

        XCTAssertEqual(
            resolution,
            .send(
                recipient: MultichainRecipient(chain: .eth, address: evmAddress),
                availableChains: [.eth, .base, .bsc]
            )
        )
    }

    func test_deeplink_primaryChainMissingFromWallet_prefersLayer1() {
        let resolution = MultichainSendRecipientResolver().resolveDeeplink(
            candidates: evmCandidates,
            walletChains: [.base, .arb, .bsc],
            network: .mainnet
        )

        XCTAssertEqual(
            resolution,
            .send(
                recipient: MultichainRecipient(chain: .bsc, address: evmAddress),
                availableChains: [.base, .arb, .bsc]
            )
        )
    }

    func test_deeplink_withoutLayer1_seedsFirstAvailableInCandidateOrder() {
        let resolution = MultichainSendRecipientResolver().resolveDeeplink(
            candidates: evmCandidates,
            walletChains: [.arb, .base],
            network: .mainnet
        )

        XCTAssertEqual(
            resolution,
            .send(
                recipient: MultichainRecipient(chain: .base, address: evmAddress),
                availableChains: [.base, .arb]
            )
        )
    }

    func test_deeplink_emptyIntersection_isUnsupported() {
        let resolution = MultichainSendRecipientResolver().resolveDeeplink(
            candidates: evmCandidates,
            walletChains: [.ton, .tron],
            network: .mainnet
        )

        XCTAssertEqual(resolution, .unsupported)
    }

    func test_deeplink_missingWalletChains_tonAndTronFallBackToLegacy() {
        for chain in [MultichainChain.ton, .tron] {
            let resolution = MultichainSendRecipientResolver().resolveDeeplink(
                candidates: MultichainRecipientCandidates(address: "address", chains: [chain]),
                walletChains: nil,
                network: .mainnet
            )

            XCTAssertEqual(resolution, .legacy, "\(chain)")
        }
    }

    func test_deeplink_missingWalletChains_otherChainsAreUnsupported() {
        let resolution = MultichainSendRecipientResolver().resolveDeeplink(
            candidates: evmCandidates,
            walletChains: nil,
            network: .mainnet
        )

        XCTAssertEqual(resolution, .unsupported)
    }

    // MARK: - resolveScan

    func test_scan_keepsSelectedChainWhenItIsACandidate() {
        let recipient = MultichainSendRecipientResolver().resolveScan(
            candidates: MultichainRecipientCandidates(address: evmAddress, chains: [.eth, .base]),
            selectedChain: .base,
            walletChains: evmChains,
            network: .mainnet
        )

        XCTAssertEqual(recipient, MultichainRecipient(chain: .base, address: evmAddress))
    }

    func test_scan_switchesToPrimaryCandidateWhenSelectedChainIsNotACandidate() {
        let recipient = MultichainSendRecipientResolver().resolveScan(
            candidates: MultichainRecipientCandidates(address: bitcoinAddress, chains: [.btc]),
            selectedChain: .eth,
            walletChains: [.eth, .btc],
            network: .mainnet
        )

        XCTAssertEqual(recipient, MultichainRecipient(chain: .btc, address: bitcoinAddress))
    }

    func test_scan_primaryCandidateMissingFromWallet_prefersLayer1() {
        let recipient = MultichainSendRecipientResolver().resolveScan(
            candidates: evmCandidates,
            selectedChain: .ton,
            walletChains: [.ton, .base, .arb, .bsc],
            network: .mainnet
        )

        XCTAssertEqual(recipient, MultichainRecipient(chain: .bsc, address: evmAddress))
    }

    func test_scan_noCandidateInWallet_returnsNil() {
        let recipient = MultichainSendRecipientResolver().resolveScan(
            candidates: MultichainRecipientCandidates(address: bitcoinAddress, chains: [.btc]),
            selectedChain: .eth,
            walletChains: [.ton, .eth],
            network: .mainnet
        )

        XCTAssertNil(recipient)
    }

    func test_scan_nilSelectedChain_fallsBackToSeedPolicy() {
        let recipient = MultichainSendRecipientResolver().resolveScan(
            candidates: evmCandidates,
            selectedChain: nil,
            walletChains: evmChains,
            network: .mainnet
        )

        XCTAssertEqual(recipient, MultichainRecipient(chain: .eth, address: evmAddress))
    }

    // MARK: - TON network gate

    func test_deeplink_testnetTonAddressOnMainnetWallet_isUnsupported() {
        let resolution = MultichainSendRecipientResolver().resolveDeeplink(
            candidates: MultichainRecipientCandidates(address: tonTestnetAddress, chains: [.ton]),
            walletChains: [.ton, .eth],
            network: .mainnet
        )

        XCTAssertEqual(resolution, .unsupported)
    }

    func test_deeplink_mainnetTonAddressOnTestnetWallet_isUnsupported() {
        let resolution = MultichainSendRecipientResolver().resolveDeeplink(
            candidates: MultichainRecipientCandidates(address: tonMainnetAddress, chains: [.ton]),
            walletChains: [.ton],
            network: .testnet
        )

        XCTAssertEqual(resolution, .unsupported)
    }

    func test_deeplink_tonAddressMatchingWalletNetwork_resolves() {
        let resolution = MultichainSendRecipientResolver().resolveDeeplink(
            candidates: MultichainRecipientCandidates(address: tonMainnetAddress, chains: [.ton]),
            walletChains: [.ton],
            network: .mainnet
        )

        XCTAssertEqual(
            resolution,
            .send(
                recipient: MultichainRecipient(chain: .ton, address: tonMainnetAddress),
                availableChains: [.ton]
            )
        )
    }

    /// A non-multichain wallet keeps going to the legacy path, which rejects the network mismatch
    /// itself and with a clearer error than `.unsupported`.
    func test_deeplink_missingWalletChains_testnetTonAddressStillFallsBackToLegacy() {
        let resolution = MultichainSendRecipientResolver().resolveDeeplink(
            candidates: MultichainRecipientCandidates(address: tonTestnetAddress, chains: [.ton]),
            walletChains: nil,
            network: .mainnet
        )

        XCTAssertEqual(resolution, .legacy)
    }

    func test_scan_testnetTonAddressOnMainnetWallet_returnsNil() {
        let recipient = MultichainSendRecipientResolver().resolveScan(
            candidates: MultichainRecipientCandidates(address: tonTestnetAddress, chains: [.ton]),
            selectedChain: .ton,
            walletChains: [.ton, .eth],
            network: .mainnet
        )

        XCTAssertNil(recipient)
    }

    func test_scan_mainnetTonAddressOnTestnetWallet_returnsNil() {
        let recipient = MultichainSendRecipientResolver().resolveScan(
            candidates: MultichainRecipientCandidates(address: tonMainnetAddress, chains: [.ton]),
            selectedChain: .ton,
            walletChains: [.ton],
            network: .testnet
        )

        XCTAssertNil(recipient)
    }

    func test_scan_tonAddressMatchingWalletNetwork_resolves() {
        let recipient = MultichainSendRecipientResolver().resolveScan(
            candidates: MultichainRecipientCandidates(address: tonMainnetAddress, chains: [.ton]),
            selectedChain: .ton,
            walletChains: [.ton],
            network: .mainnet
        )

        XCTAssertEqual(recipient, MultichainRecipient(chain: .ton, address: tonMainnetAddress))
    }
}

private extension MultichainSendRecipientResolverTests {
    var evmCandidates: MultichainRecipientCandidates {
        MultichainRecipientCandidates(address: evmAddress, chains: evmChains)
    }
}
