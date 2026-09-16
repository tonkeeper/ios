@testable import KeeperCore
import ReownWalletKit
import TonSwift
import XCTest

final class WalletConnectSessionNamespaceBuilderTests: XCTestCase {
    func testProposalNamespacesMapsRequiredAndOptionalNamespaces() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))

        let namespaces = builder.proposalNamespaces(
            requiredNamespaces: [
                "eip155": ProposalNamespace(
                    chains: [eth],
                    methods: [WalletConnectMethod.personalSign.rawValue, "unsupported_method"],
                    events: ["accountsChanged"]
                ),
            ],
            optionalNamespaces: [
                WalletConnectChain.tron.caip2: ProposalNamespace(
                    methods: [WalletConnectMethod.tronSignMessage.rawValue],
                    events: ["chainChanged"]
                ),
            ]
        )

        XCTAssertEqual(namespaces.count, 2)
        let required = try XCTUnwrap(namespaces.first { $0.key == "eip155" })
        XCTAssertEqual(required.chains, [.eth])
        XCTAssertEqual(required.methods, [.personalSign])
        XCTAssertEqual(required.events, ["accountsChanged"])
        XCTAssertTrue(required.isRequired)

        let optional = try XCTUnwrap(namespaces.first { $0.key == WalletConnectChain.tron.caip2 })
        XCTAssertEqual(optional.chains, [.tron])
        XCTAssertEqual(optional.methods, [.tronSignMessage])
        XCTAssertEqual(optional.events, ["chainChanged"])
        XCTAssertFalse(optional.isRequired)
    }

    func testSessionNamespacesRejectsUnsupportedRequiredMethods() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))

        do {
            _ = try builder.sessionNamespaces(
                requiredNamespaces: [
                    "eip155": ProposalNamespace(
                        chains: [eth],
                        methods: ["unsupported_method"],
                        events: []
                    ),
                ],
                optionalNamespaces: nil,
                walletConnectAccounts: [
                    WalletConnectAccount(chain: .eth, address: "0xabc"),
                ]
            )
            XCTFail("Expected unsupported required methods error")
        } catch {
            XCTAssertEqual(error, .unsupportedRequiredMethods(["unsupported_method"]))
        }
    }

    func testSessionNamespacesApprovesWalletGetCapabilitiesForEVMNamespaces() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))

        let namespaces = try builder.sessionNamespaces(
            requiredNamespaces: [
                "eip155": ProposalNamespace(
                    chains: [eth],
                    methods: [WalletConnectMethod.walletGetCapabilities.rawValue],
                    events: []
                ),
            ],
            optionalNamespaces: nil,
            walletConnectAccounts: [
                WalletConnectAccount(chain: .eth, address: "0xabc"),
            ]
        )

        XCTAssertEqual(namespaces["eip155"]?.methods, [WalletConnectMethod.walletGetCapabilities.rawValue])
    }

    func testSessionNamespacesRejectsRequiredWalletSendCalls() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))

        do {
            _ = try builder.sessionNamespaces(
                requiredNamespaces: [
                    "eip155": ProposalNamespace(
                        chains: [eth],
                        methods: ["wallet_sendCalls"],
                        events: []
                    ),
                ],
                optionalNamespaces: nil,
                walletConnectAccounts: [
                    WalletConnectAccount(chain: .eth, address: "0xabc"),
                ]
            )
            XCTFail("Expected unsupported required methods error")
        } catch {
            XCTAssertEqual(error, .unsupportedRequiredMethods(["wallet_sendCalls"]))
        }
    }

    func testSessionNamespacesRejectsEVMRequiredMethodInTronNamespace() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let tron = try XCTUnwrap(Blockchain(WalletConnectChain.tron.caip2))

        do {
            _ = try builder.sessionNamespaces(
                requiredNamespaces: [
                    "tron": ProposalNamespace(
                        chains: [tron],
                        methods: [WalletConnectMethod.ethSendTransaction.rawValue],
                        events: []
                    ),
                ],
                optionalNamespaces: nil,
                walletConnectAccounts: [
                    WalletConnectAccount(chain: .tron, address: "TXYZ"),
                ]
            )
            XCTFail("Expected unsupported required methods error")
        } catch {
            XCTAssertEqual(error, .unsupportedRequiredMethods([WalletConnectMethod.ethSendTransaction.rawValue]))
        }
    }

    func testSessionNamespacesRejectsTronRequiredMethodInEIP155Namespace() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))

        do {
            _ = try builder.sessionNamespaces(
                requiredNamespaces: [
                    "eip155": ProposalNamespace(
                        chains: [eth],
                        methods: [WalletConnectMethod.tronSignTransaction.rawValue],
                        events: []
                    ),
                ],
                optionalNamespaces: nil,
                walletConnectAccounts: [
                    WalletConnectAccount(chain: .eth, address: "0xabc"),
                ]
            )
            XCTFail("Expected unsupported required methods error")
        } catch {
            XCTAssertEqual(error, .unsupportedRequiredMethods([WalletConnectMethod.tronSignTransaction.rawValue]))
        }
    }

    func testSessionNamespacesApprovesSupportedRequiredEvents() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))

        let namespaces = try builder.sessionNamespaces(
            requiredNamespaces: [
                "eip155": ProposalNamespace(
                    chains: [eth],
                    methods: [WalletConnectMethod.personalSign.rawValue],
                    events: ["accountsChanged", "chainChanged"]
                ),
            ],
            optionalNamespaces: nil,
            walletConnectAccounts: [
                WalletConnectAccount(chain: .eth, address: "0xabc"),
            ]
        )

        XCTAssertEqual(namespaces["eip155"]?.events, ["accountsChanged", "chainChanged"])
    }

    func testSessionNamespacesRejectsUnsupportedRequiredEvents() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))

        do {
            _ = try builder.sessionNamespaces(
                requiredNamespaces: [
                    "eip155": ProposalNamespace(
                        chains: [eth],
                        methods: [WalletConnectMethod.personalSign.rawValue],
                        events: ["unsupportedEvent"]
                    ),
                ],
                optionalNamespaces: nil,
                walletConnectAccounts: [
                    WalletConnectAccount(chain: .eth, address: "0xabc"),
                ]
            )
            XCTFail("Expected unsupported required events error")
        } catch {
            XCTAssertEqual(error, .unsupportedRequiredMethods(["unsupportedEvent"]))
        }
    }

    func testSessionNamespacesIgnoresMissingOptionalChains() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))
        let tron = try XCTUnwrap(Blockchain(WalletConnectChain.tron.caip2))

        let namespaces = try builder.sessionNamespaces(
            requiredNamespaces: [
                "eip155": ProposalNamespace(
                    chains: [eth],
                    methods: [WalletConnectMethod.personalSign.rawValue],
                    events: []
                ),
            ],
            optionalNamespaces: [
                "tron": ProposalNamespace(
                    chains: [tron],
                    methods: [WalletConnectMethod.tronSignMessage.rawValue],
                    events: ["chainChanged"]
                ),
            ],
            walletConnectAccounts: [
                WalletConnectAccount(chain: .eth, address: "0xabc"),
            ]
        )

        XCTAssertEqual(namespaces.keys.sorted(), ["eip155"])
        let namespace = try XCTUnwrap(namespaces["eip155"])
        XCTAssertEqual(namespace.chains, [eth])
        XCTAssertEqual(namespace.accounts.map(\.absoluteString), ["eip155:1:0xabc"])
        XCTAssertEqual(namespace.methods, [WalletConnectMethod.personalSign.rawValue])
        XCTAssertEqual(namespace.events, [])
    }

    func testSessionNamespacesIgnoresOptionalMethodsThatDoNotMatchNamespace() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))

        let namespaces = try builder.sessionNamespaces(
            requiredNamespaces: [
                "eip155": ProposalNamespace(
                    chains: [eth],
                    methods: [WalletConnectMethod.personalSign.rawValue],
                    events: []
                ),
            ],
            optionalNamespaces: [
                "eip155": ProposalNamespace(
                    chains: [eth],
                    methods: [
                        WalletConnectMethod.tronSignTransaction.rawValue,
                        WalletConnectMethod.ethSendTransaction.rawValue,
                    ],
                    events: []
                ),
            ],
            walletConnectAccounts: [
                WalletConnectAccount(chain: .eth, address: "0xabc"),
            ]
        )

        let namespace = try XCTUnwrap(namespaces["eip155"])
        XCTAssertEqual(
            namespace.methods,
            [
                WalletConnectMethod.personalSign.rawValue,
                WalletConnectMethod.ethSendTransaction.rawValue,
            ]
        )
    }

    func testSessionNamespacesDoesNotApproveOptionalWalletSendCalls() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))

        let namespaces = try builder.sessionNamespaces(
            requiredNamespaces: [
                "eip155": ProposalNamespace(
                    chains: [eth],
                    methods: [WalletConnectMethod.personalSign.rawValue],
                    events: []
                ),
            ],
            optionalNamespaces: [
                "eip155": ProposalNamespace(
                    chains: [eth],
                    methods: ["wallet_sendCalls"],
                    events: []
                ),
            ],
            walletConnectAccounts: [
                WalletConnectAccount(chain: .eth, address: "0xabc"),
            ]
        )

        let namespace = try XCTUnwrap(namespaces["eip155"])
        XCTAssertEqual(namespace.methods, [WalletConnectMethod.personalSign.rawValue])
    }

    func testSessionNamespacesApprovesValidEVMTronAndTONMethods() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))
        let tron = try XCTUnwrap(Blockchain(WalletConnectChain.tron.caip2))
        let ton = try XCTUnwrap(Blockchain(WalletConnectChain.ton.caip2))

        let namespaces = try builder.sessionNamespaces(
            requiredNamespaces: [
                "eip155": ProposalNamespace(
                    chains: [eth],
                    methods: Set(WalletConnectMethod.evmMethods.map(\.rawValue)),
                    events: []
                ),
                "tron": ProposalNamespace(
                    chains: [tron],
                    methods: Set(WalletConnectMethod.tronMethods.map(\.rawValue)),
                    events: []
                ),
                "ton": ProposalNamespace(
                    chains: [ton],
                    methods: Set(WalletConnectMethod.tonMethods.map(\.rawValue)),
                    events: []
                ),
            ],
            optionalNamespaces: nil,
            walletConnectAccounts: [
                WalletConnectAccount(chain: .eth, address: "0xabc"),
                WalletConnectAccount(chain: .tron, address: "TXYZ"),
                WalletConnectAccount(chain: .ton, address: "EQDmnxDMhId6v1Ofg_h5KR5coWlFG6e86Ro3pc7Tq4CA0-Jn"),
            ]
        )

        XCTAssertEqual(namespaces["eip155"]?.methods, Set(WalletConnectMethod.evmMethods.map(\.rawValue)))
        XCTAssertEqual(namespaces["tron"]?.methods, Set(WalletConnectMethod.tronMethods.map(\.rawValue)))
        XCTAssertEqual(namespaces["ton"]?.methods, Set(WalletConnectMethod.tonMethods.map(\.rawValue)))
    }

    func testSessionNamespacesRejectsUnsupportedReownEVMMethodsWithoutOverApproving() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))

        let requestedMethods: Set<String> = [
            WalletConnectMethod.ethSignTypedDataV4.rawValue,
            WalletConnectMethod.personalSign.rawValue,
            "eth_sign",
            "eth_signTypedData",
            "wallet_switchEthereumChain",
        ]

        do {
            _ = try builder.sessionNamespaces(
                requiredNamespaces: [
                    "eip155": ProposalNamespace(
                        chains: [eth],
                        methods: requestedMethods,
                        events: ["accountsChanged", "chainChanged"]
                    ),
                ],
                optionalNamespaces: nil,
                walletConnectAccounts: [
                    WalletConnectAccount(chain: .eth, address: "0xabc"),
                ]
            )
            XCTFail("Expected unsupported Reown methods to be rejected")
        } catch {
            XCTAssertEqual(error, .unsupportedRequiredMethods([
                "eth_sign",
                "eth_signTypedData",
            ]))
        }
    }

    func testSessionNamespacesApprovesTONMethodsWithRequestHandlingStubs() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let ton = try XCTUnwrap(Blockchain(WalletConnectChain.ton.caip2))

        let namespaces = try builder.sessionNamespaces(
            requiredNamespaces: [
                "ton": ProposalNamespace(
                    chains: [ton],
                    methods: ["ton_sendMessage", "ton_signData"],
                    events: []
                ),
            ],
            optionalNamespaces: nil,
            walletConnectAccounts: [
                WalletConnectAccount(chain: .ton, address: "EQDmnxDMhId6v1Ofg_h5KR5coWlFG6e86Ro3pc7Tq4CA0-Jn"),
            ]
        )

        XCTAssertEqual(namespaces["ton"]?.methods, ["ton_sendMessage", "ton_signData"])
    }

    func testSessionNamespacesInfersTONMainnetForNamespaceOnlyProposal() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let ton = try XCTUnwrap(Blockchain(WalletConnectChain.ton.caip2))
        let address = "EQDmnxDMhId6v1Ofg_h5KR5coWlFG6e86Ro3pc7Tq4CA0-Jn"

        let proposalNamespaces = builder.proposalNamespaces(
            requiredNamespaces: [
                "ton": ProposalNamespace(
                    methods: Set(WalletConnectMethod.tonMethods.map(\.rawValue)),
                    events: []
                ),
            ],
            optionalNamespaces: nil
        )
        XCTAssertEqual(proposalNamespaces.first?.chains, [.ton])

        let namespaces = try builder.sessionNamespaces(
            requiredNamespaces: [
                "ton": ProposalNamespace(
                    methods: Set(WalletConnectMethod.tonMethods.map(\.rawValue)),
                    events: []
                ),
            ],
            optionalNamespaces: nil,
            walletConnectAccounts: [
                WalletConnectAccount(chain: .ton, address: address),
            ]
        )

        let namespace = try XCTUnwrap(namespaces["ton"])
        XCTAssertEqual(namespace.chains, [ton])
        XCTAssertEqual(namespace.accounts.map(\.absoluteString), ["ton:-239:\(address)"])
        XCTAssertEqual(namespace.methods, Set(WalletConnectMethod.tonMethods.map(\.rawValue)))
        XCTAssertEqual(namespace.events, [])
    }

    func testSessionNamespacesOmitsOptionalEvents() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))
        let tron = try XCTUnwrap(Blockchain(WalletConnectChain.tron.caip2))

        let namespaces = try builder.sessionNamespaces(
            requiredNamespaces: [
                "eip155": ProposalNamespace(
                    chains: [eth],
                    methods: [WalletConnectMethod.personalSign.rawValue],
                    events: []
                ),
            ],
            optionalNamespaces: [
                "tron": ProposalNamespace(
                    chains: [tron],
                    methods: [WalletConnectMethod.tronSignMessage.rawValue],
                    events: ["chainChanged"]
                ),
            ],
            walletConnectAccounts: [
                WalletConnectAccount(chain: .eth, address: "0xabc"),
                WalletConnectAccount(chain: .tron, address: "TXYZ"),
            ]
        )

        let optionalNamespace = try XCTUnwrap(namespaces["tron"])
        XCTAssertEqual(optionalNamespace.methods, [WalletConnectMethod.tronSignMessage.rawValue])
        XCTAssertEqual(optionalNamespace.events, [])
    }

    func testSessionPropertiesAddsTronMethodVersionForTronNamespaces() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))
        let tron = try XCTUnwrap(Blockchain(WalletConnectChain.tron.caip2))
        let ethAccount = try XCTUnwrap(WalletConnectUtils.Account(blockchain: eth, address: "0xabc"))
        let tronAccount = try XCTUnwrap(WalletConnectUtils.Account(blockchain: tron, address: "TXYZ"))

        XCTAssertNil(
            try builder.sessionProperties(
                for: [
                    "eip155": SessionNamespace(
                        chains: [eth],
                        accounts: [ethAccount],
                        methods: [WalletConnectMethod.personalSign.rawValue],
                        events: []
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try builder.sessionProperties(
                for: [
                    "tron": SessionNamespace(
                        chains: [tron],
                        accounts: [tronAccount],
                        methods: [WalletConnectMethod.tronSignMessage.rawValue],
                        events: []
                    ),
                ]
            ),
            ["tron_method_version": "v1"]
        )
    }

    func testSessionPropertiesAddsTONPropertiesForTONNamespaces() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let ton = try XCTUnwrap(Blockchain(WalletConnectChain.ton.caip2))
        let tonAccount = try XCTUnwrap(WalletConnectUtils.Account(
            blockchain: ton,
            address: "EQDmnxDMhId6v1Ofg_h5KR5coWlFG6e86Ro3pc7Tq4CA0-Jn"
        ))

        let properties = try builder.sessionProperties(
            for: [
                "ton": SessionNamespace(
                    chains: [ton],
                    accounts: [tonAccount],
                    methods: [],
                    events: []
                ),
            ],
            wallet: makeWallet()
        )

        XCTAssertEqual(properties?["ton_getPublicKey"], String(repeating: "01", count: 32))
        XCTAssertFalse(properties?["ton_getStateInit"]?.isEmpty ?? true)
    }

    func testScopedPropertiesAddsAtomicUnsupportedForEVMNamespacesOnly() throws {
        let builder = WalletConnectSessionNamespaceBuilder()
        let eth = try XCTUnwrap(Blockchain(WalletConnectChain.eth.caip2))
        let tron = try XCTUnwrap(Blockchain(WalletConnectChain.tron.caip2))
        let ethAccount = try XCTUnwrap(WalletConnectUtils.Account(blockchain: eth, address: "0xabc"))
        let tronAccount = try XCTUnwrap(WalletConnectUtils.Account(blockchain: tron, address: "TXYZ"))

        XCTAssertEqual(
            builder.scopedProperties(
                for: [
                    "eip155": SessionNamespace(
                        chains: [eth],
                        accounts: [ethAccount],
                        methods: [WalletConnectMethod.walletGetCapabilities.rawValue],
                        events: []
                    ),
                ]
            ),
            ["eip155:1": #"{"atomic":{"status":"unsupported"}}"#]
        )
        XCTAssertNil(
            builder.scopedProperties(
                for: [
                    "tron": SessionNamespace(
                        chains: [tron],
                        accounts: [tronAccount],
                        methods: [WalletConnectMethod.tronSignMessage.rawValue],
                        events: []
                    ),
                ]
            )
        )
    }

    func testSessionNamespacesNormalizesInlineChainKeys() throws {
        let builder = WalletConnectSessionNamespaceBuilder()

        let namespaces = try builder.sessionNamespaces(
            requiredNamespaces: [
                WalletConnectChain.eth.caip2: ProposalNamespace(
                    methods: [WalletConnectMethod.personalSign.rawValue],
                    events: []
                ),
            ],
            optionalNamespaces: nil,
            walletConnectAccounts: [
                WalletConnectAccount(chain: .eth, address: "0xabc"),
            ]
        )

        XCTAssertEqual(namespaces.keys.sorted(), ["eip155"])
    }

    func makeWallet() -> Wallet {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 0x01, count: 32))
        return Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(.init(walletId: "wallet", addresses: [
                MultichainWalletAddress(
                    chain: .ton,
                    address: "EQDmnxDMhId6v1Ofg_h5KR5coWlFG6e86Ro3pc7Tq4CA0-Jn"
                ),
            ]))
        )
    }
}
