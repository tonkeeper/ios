@testable import KeeperCore
import TronSwift
import XCTest

final class MultichainRecipientDetectionTests: XCTestCase {
    private let evmAddress = "0x000000000000000000000000000000000000dead"
    private let bitcoinAddress = "1BoatSLRHtKNngkdXEeobR76b53LETtpyT"
    /// The zero address in all four user-friendly forms: the tag byte carries both the bounceable
    /// and the test-only flag, so these differ only by network and bounceability.
    private let tonAddress = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
    private let tonMainnetNonBounceable = "UQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJKZ"
    private let tonTestnetBounceable = "kQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHTW"
    private let tonTestnetNonBounceable = "0QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACkT"
    private let tonRawAddress = "0:0000000000000000000000000000000000000000000000000000000000000000"
    /// The pair from the support report the network check was added for.
    private let reportedMainnetAddress = "UQBcmqkZxhc81WNeFFzq9ZX6qBlP28B-MuYeSxpS_-YMIDNl"
    private let reportedTestnetAddress = "0QAfY673Jt4NZZoy1pNjzv4da419kXisdhsJRx6F6_qwOopM"

    // MARK: - MultichainRecipientCandidates(string:)

    func test_candidates_bareEVMAddress_offerEveryEVMChain() {
        let candidates = MultichainRecipientCandidates(string: evmAddress)

        XCTAssertEqual(candidates?.address, evmAddress)
        XCTAssertEqual(candidates.map { Set($0.chains) }, [.eth, .base, .arb, .bsc])
    }

    func test_candidates_detectChecksummedEthereumRawAddress() {
        let candidates = MultichainRecipientCandidates(
            string: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
        )

        XCTAssertEqual(candidates.map { Set($0.chains) }, [.eth, .base, .arb, .bsc])
    }

    func test_candidates_detectUppercaseEthereumRawAddress() {
        let candidates = MultichainRecipientCandidates(
            string: "0xD8DA6BF26964AF9D7EED9E03E53415D37AA96045"
        )

        XCTAssertEqual(candidates.map { Set($0.chains) }, [.eth, .base, .arb, .bsc])
    }

    func test_candidates_tronAddress_offersTronOnly() {
        let candidates = MultichainRecipientCandidates(string: TronSwift.USDT.address.base58)

        XCTAssertEqual(candidates?.chains, [.tron])
    }

    func test_candidates_tonAddress_offersTonOnly() {
        let candidates = MultichainRecipientCandidates(string: tonAddress)

        XCTAssertEqual(candidates?.chains, [.ton])
    }

    func test_candidates_bitcoinAddress_offersBitcoinOnly() {
        let candidates = MultichainRecipientCandidates(string: bitcoinAddress)

        XCTAssertEqual(candidates?.chains, [.btc])
    }

    func test_candidates_trimWhitespace() {
        let candidates = MultichainRecipientCandidates(string: "  \(evmAddress)\n")

        XCTAssertEqual(candidates?.address, evmAddress)
    }

    func test_candidates_nilForInvalidPayload() {
        XCTAssertNil(MultichainRecipientCandidates(string: "ethereum:\(evmAddress)@8453"))
        XCTAssertNil(MultichainRecipientCandidates(string: "not-an-address"))
    }

    func test_candidates_nilForEmptyString() {
        XCTAssertNil(MultichainRecipientCandidates(string: ""))
        XCTAssertNil(MultichainRecipientCandidates(string: "   "))
    }

    // MARK: - MultichainRecipient(string:chain:network:)

    func test_recipient_acceptsEVMAddressOnEveryEVMChain() {
        for chain in [MultichainChain.eth, .base, .arb, .bsc] {
            XCTAssertEqual(
                MultichainRecipient(string: evmAddress, chain: chain, network: .mainnet),
                MultichainRecipient(chain: chain, address: evmAddress),
                "\(chain)"
            )
        }
    }

    func test_recipient_rejectsAddressOnMismatchedChain() {
        for chain in [MultichainChain.btc, .ton, .tron] {
            XCTAssertNil(
                MultichainRecipient(string: evmAddress, chain: chain, network: .mainnet),
                "\(chain)"
            )
        }
    }

    func test_recipient_trimsWhitespace() {
        XCTAssertEqual(
            MultichainRecipient(string: "  \(evmAddress)\n", chain: .eth, network: .mainnet),
            MultichainRecipient(chain: .eth, address: evmAddress)
        )
    }

    func test_recipient_rejectsEmptyString() {
        XCTAssertNil(MultichainRecipient(string: "   ", chain: .eth, network: .mainnet))
    }

    // MARK: - Network.matchesTonAddress

    func test_matchesTonAddress_mainnetAcceptsMainnetTaggedAddressesOnly() {
        XCTAssertTrue(Network.mainnet.matchesTonAddress(tonAddress))
        XCTAssertTrue(Network.mainnet.matchesTonAddress(tonMainnetNonBounceable))
        XCTAssertFalse(Network.mainnet.matchesTonAddress(tonTestnetBounceable))
        XCTAssertFalse(Network.mainnet.matchesTonAddress(tonTestnetNonBounceable))
    }

    func test_matchesTonAddress_testnetAcceptsTestnetTaggedAddressesOnly() {
        XCTAssertTrue(Network.testnet.matchesTonAddress(tonTestnetBounceable))
        XCTAssertTrue(Network.testnet.matchesTonAddress(tonTestnetNonBounceable))
        XCTAssertFalse(Network.testnet.matchesTonAddress(tonAddress))
        XCTAssertFalse(Network.testnet.matchesTonAddress(tonMainnetNonBounceable))
    }

    /// Raw addresses carry no tag byte, so they belong to either network and must keep working.
    func test_matchesTonAddress_rawAddressBelongsToEitherNetwork() {
        XCTAssertTrue(Network.mainnet.matchesTonAddress(tonRawAddress))
        XCTAssertTrue(Network.testnet.matchesTonAddress(tonRawAddress))
    }

    func test_matchesTonAddress_nonTonPayloadIsLeftToTheChainItBelongsTo() {
        XCTAssertTrue(Network.mainnet.matchesTonAddress(evmAddress))
        XCTAssertTrue(Network.mainnet.matchesTonAddress(bitcoinAddress))
        XCTAssertTrue(Network.mainnet.matchesTonAddress("not-an-address"))
    }

    func test_matchesTonAddress_reportedSupportCase() {
        XCTAssertTrue(Network.mainnet.matchesTonAddress(reportedMainnetAddress))
        XCTAssertFalse(Network.mainnet.matchesTonAddress(reportedTestnetAddress))
    }

    // MARK: - filteringNetworkMismatch

    func test_filteringNetworkMismatch_dropsTestnetTonAddressForMainnetWallet() {
        let candidates = MultichainRecipientCandidates(string: reportedTestnetAddress)

        XCTAssertEqual(candidates?.chains, [.ton])
        XCTAssertNil(candidates?.filteringNetworkMismatch(.mainnet))
    }

    func test_filteringNetworkMismatch_dropsMainnetTonAddressForTestnetWallet() {
        let candidates = MultichainRecipientCandidates(string: reportedMainnetAddress)

        XCTAssertNil(candidates?.filteringNetworkMismatch(.testnet))
    }

    func test_filteringNetworkMismatch_keepsMatchingTonAddress() {
        let candidates = MultichainRecipientCandidates(string: reportedMainnetAddress)

        XCTAssertEqual(candidates?.filteringNetworkMismatch(.mainnet), candidates)
        XCTAssertEqual(
            MultichainRecipientCandidates(string: reportedTestnetAddress)?.filteringNetworkMismatch(.testnet),
            MultichainRecipientCandidates(string: reportedTestnetAddress)
        )
    }

    func test_filteringNetworkMismatch_leavesNonTonChainsUntouched() {
        for address in [evmAddress, bitcoinAddress, TronSwift.USDT.address.base58] {
            let candidates = MultichainRecipientCandidates(string: address)

            XCTAssertEqual(candidates?.filteringNetworkMismatch(.mainnet), candidates, address)
            XCTAssertEqual(candidates?.filteringNetworkMismatch(.testnet), candidates, address)
        }
    }

    // MARK: - MultichainRecipient network gate

    func test_recipient_rejectsTestnetTonAddressOnMainnetWallet() {
        XCTAssertNil(MultichainRecipient(string: reportedTestnetAddress, chain: .ton, network: .mainnet))
        XCTAssertNil(MultichainRecipient(string: tonTestnetBounceable, chain: .ton, network: .mainnet))
    }

    func test_recipient_rejectsMainnetTonAddressOnTestnetWallet() {
        XCTAssertNil(MultichainRecipient(string: reportedMainnetAddress, chain: .ton, network: .testnet))
        XCTAssertNil(MultichainRecipient(string: tonAddress, chain: .ton, network: .testnet))
    }

    func test_recipient_acceptsTonAddressMatchingTheWalletNetwork() {
        XCTAssertEqual(
            MultichainRecipient(string: reportedMainnetAddress, chain: .ton, network: .mainnet),
            MultichainRecipient(chain: .ton, address: reportedMainnetAddress)
        )
        XCTAssertEqual(
            MultichainRecipient(string: reportedTestnetAddress, chain: .ton, network: .testnet),
            MultichainRecipient(chain: .ton, address: reportedTestnetAddress)
        )
    }

    func test_recipient_acceptsEVMAddressRegardlessOfWalletNetwork() {
        for network in [Network.mainnet, .testnet] {
            XCTAssertEqual(
                MultichainRecipient(string: evmAddress, chain: .eth, network: network),
                MultichainRecipient(chain: .eth, address: evmAddress),
                "\(network)"
            )
        }
    }
}
