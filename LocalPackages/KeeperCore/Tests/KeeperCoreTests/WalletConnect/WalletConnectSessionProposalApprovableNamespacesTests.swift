@testable import KeeperCore
import TonSwift
import XCTest

final class WalletConnectSessionProposalApprovableNamespacesTests: XCTestCase {
    func testNamespaceWithoutAppSupportedChainsIsDropped() {
        let proposal = makeProposal(namespaces: [
            makeNamespace(key: "eip155", chains: [], methods: [.ethSendTransaction]),
        ])

        XCTAssertEqual(proposal.approvableNamespaces(wallet: makeWallet()), [])
    }

    func testNamespaceWithoutWalletAddressIsDropped() {
        let proposal = makeProposal(namespaces: [
            makeNamespace(key: "tron", chains: [.tron], methods: [.tronSignTransaction]),
        ])

        XCTAssertEqual(proposal.approvableNamespaces(wallet: makeWallet()), [])
    }

    func testNamespaceWithoutMethodsIsDropped() {
        let proposal = makeProposal(namespaces: [
            makeNamespace(key: "eip155", chains: [.eth], methods: []),
        ])

        XCTAssertEqual(proposal.approvableNamespaces(wallet: makeWallet()), [])
    }

    func testNamespaceChainsAreFilteredToWalletAddresses() {
        let namespace = makeNamespace(key: "eip155", chains: [.eth, .base], methods: [.personalSign])
        let proposal = makeProposal(namespaces: [namespace])

        var expected = namespace
        expected.chains = [.eth]
        XCTAssertEqual(proposal.approvableNamespaces(wallet: makeWallet()), [expected])
    }

    func testOnlyNamespacesSatisfiableByWalletSurvive() {
        let tonNamespace = makeNamespace(key: "ton", chains: [.ton], methods: [.tonSendMessage])
        let tronNamespace = makeNamespace(key: "tron", chains: [.tron], methods: [.tronSignTransaction])
        let proposal = makeProposal(namespaces: [tonNamespace, tronNamespace])

        XCTAssertEqual(proposal.approvableNamespaces(wallet: makeWallet()), [tonNamespace])
    }

    func testCanBeApprovedFailsWhenRequiredChainHasNoWalletAddress() {
        let proposal = makeProposal(namespaces: [
            makeNamespace(key: "eip155", chains: [.eth], methods: [.personalSign], isRequired: true),
            makeNamespace(key: "tron", chains: [.tron], methods: [.tronSignTransaction], isRequired: true),
        ])

        XCTAssertFalse(proposal.canBeApproved(wallet: makeWallet()))
    }

    func testCanBeApprovedFailsWhenNothingIsApprovable() {
        let proposal = makeProposal(namespaces: [
            makeNamespace(key: "tron", chains: [.tron], methods: [.tronSignTransaction]),
        ])

        XCTAssertFalse(proposal.canBeApproved(wallet: makeWallet()))
    }

    func testCanBeApprovedAllowsUnsatisfiableOptionalNamespaces() {
        let proposal = makeProposal(namespaces: [
            makeNamespace(key: "eip155", chains: [.eth], methods: [.personalSign], isRequired: true),
            makeNamespace(key: "tron", chains: [.tron], methods: [.tronSignTransaction]),
        ])

        XCTAssertTrue(proposal.canBeApproved(wallet: makeWallet()))
    }

    func testTheFirstWalletThatCanApproveIsPreferred() {
        let proposal = makeProposal(namespaces: [
            makeNamespace(key: "eip155", chains: [.eth], methods: [.personalSign]),
        ])
        let withoutEthereum = makeWallet(id: "tron-only", addresses: [MultichainWalletAddress(chain: .tron, address: "TRON")])

        XCTAssertEqual(proposal.preferredWallet(among: [withoutEthereum, makeWallet()])?.id, "wallet")
    }

    func testWithoutAWalletThatCanApproveTheFirstOneIsKept() {
        let proposal = makeProposal(namespaces: [
            makeNamespace(key: "tron", chains: [.tron], methods: [.tronSignTransaction], isRequired: true),
        ])

        XCTAssertEqual(proposal.preferredWallet(among: [makeWallet(), makeWallet(id: "other")])?.id, "wallet")
    }
}

private extension WalletConnectSessionProposalApprovableNamespacesTests {
    func makeProposal(namespaces: [WalletConnectProposalNamespace]) -> WalletConnectSessionProposal {
        WalletConnectSessionProposal(
            id: "proposal",
            pairingTopic: "pairing-topic",
            dapp: WalletConnectDapp(
                name: "dapp",
                url: "https://example.com",
                description: "",
                iconURL: nil
            ),
            namespaces: namespaces,
            validation: .valid,
            source: .deeplink
        )
    }

    func makeNamespace(
        key: String,
        chains: [WalletConnectChain],
        methods: Set<WalletConnectMethod>,
        isRequired: Bool = false
    ) -> WalletConnectProposalNamespace {
        WalletConnectProposalNamespace(
            key: key,
            chains: chains,
            methods: methods,
            events: [],
            isRequired: isRequired
        )
    }

    func makeWallet(
        id: String = "wallet",
        addresses: [MultichainWalletAddress] = [
            MultichainWalletAddress(chain: .ton, address: "ton-v4r2", type: .tonV4R2),
            MultichainWalletAddress(chain: .eth, address: "0xabc"),
        ]
    ) -> Wallet {
        Wallet(
            id: id,
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(
                    TonSwift.PublicKey(data: Data(repeating: 0x01, count: 32)),
                    .v4R2
                )
            ),
            metaData: WalletMetaData(
                label: "wallet",
                tintColor: .SteelGray,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "multichain-wallet",
                    addresses: addresses,
                    syncState: .synced
                )
            )
        )
    }
}
