import Foundation
import ReownWalletKit
import TonSwift

struct WalletConnectSessionNamespaceBuilder {
    static func chains(from namespaces: [String: SessionNamespace]) -> [WalletConnectChain] {
        let chains = Set(namespaces.values.flatMap { namespace in
            ((namespace.chains ?? []) + namespace.accounts.map(\.blockchain))
                .compactMap { WalletConnectChain(caip2: $0.absoluteString) }
        })
        return WalletConnectChain.allCases.filter(chains.contains)
    }

    func proposalNamespaces(
        requiredNamespaces: [String: ProposalNamespace],
        optionalNamespaces: [String: ProposalNamespace]?
    ) -> [WalletConnectProposalNamespace] {
        let required = requiredNamespaces.map {
            WalletConnectProposalNamespace(
                key: $0.key,
                chains: chains(namespaceKey: $0.key, namespace: $0.value),
                methods: methods($0.value.methods, namespaceKey: $0.key, namespace: $0.value),
                events: $0.value.events,
                isRequired: true
            )
        }
        let optional = optionalNamespaces?.map {
            WalletConnectProposalNamespace(
                key: $0.key,
                chains: chains(namespaceKey: $0.key, namespace: $0.value),
                methods: methods($0.value.methods, namespaceKey: $0.key, namespace: $0.value),
                events: $0.value.events,
                isRequired: false
            )
        } ?? []
        return required + optional
    }

    func sessionNamespaces(
        requiredNamespaces: [String: ProposalNamespace],
        optionalNamespaces: [String: ProposalNamespace]?,
        walletConnectAccounts: [WalletConnectAccount]
    ) throws(WalletConnectSessionApprovalError) -> [String: SessionNamespace] {
        let blockchainsByChain = Dictionary(uniqueKeysWithValues: walletConnectAccounts.compactMap { account -> (WalletConnectChain, Blockchain)? in
            guard let blockchain = Blockchain(account.chain.caip2) else { return nil }
            return (account.chain, blockchain)
        })
        let accountsByBlockchain = Dictionary(grouping: walletConnectAccounts.compactMap { account -> (Blockchain, WalletConnectUtils.Account)? in
            guard let blockchain = blockchainsByChain[account.chain],
                  let wcAccount = WalletConnectUtils.Account(
                      blockchain: blockchain,
                      address: account.address
                  )
            else {
                return nil
            }
            return (blockchain, wcAccount)
        }, by: \.0)
            .mapValues { $0.map(\.1) }

        var result = [String: SessionNamespace]()
        try addNamespaces(
            requiredNamespaces,
            required: true,
            accountsByBlockchain: accountsByBlockchain,
            result: &result
        )
        if let optionalNamespaces = optionalNamespaces {
            try addNamespaces(
                optionalNamespaces,
                required: false,
                accountsByBlockchain: accountsByBlockchain,
                result: &result
            )
        }

        if result.isEmpty {
            throw .unsupportedRequiredChains(requiredNamespaces.keys.sorted())
        }
        return result
    }

    func sessionProperties(
        for namespaces: [String: SessionNamespace],
        wallet: Wallet? = nil
    ) throws(WalletConnectSessionApprovalError) -> [String: String]? {
        var properties = [String: String]()

        let hasTronNamespace = namespaces.values.contains { namespace in
            namespace.chains?.contains(where: { $0.namespace == WalletConnectChain.tron.namespace }) == true
                || namespace.accounts.contains(where: { $0.namespace == WalletConnectChain.tron.namespace })
        }
        if hasTronNamespace {
            properties["tron_method_version"] = "v1"
        }

        let hasTONNamespace = namespaces.values.contains { namespace in
            namespace.chains?.contains(where: { $0.namespace == WalletConnectChain.ton.namespace }) == true
                || namespace.accounts.contains(where: { $0.namespace == WalletConnectChain.ton.namespace })
        }
        if hasTONNamespace {
            guard let wallet else {
                throw .invalidAccount(chain: .ton)
            }
            do {
                properties["ton_getPublicKey"] = try wallet.publicKey.data.hexString()
                properties["ton_getStateInit"] = try walletConnectTONStateInit(wallet: wallet)
            } catch {
                throw .invalidAccount(chain: .ton)
            }
        }

        return properties.isEmpty ? nil : properties
    }

    func scopedProperties(
        for namespaces: [String: SessionNamespace]
    ) -> [String: String]? {
        let evmChainIds = Set(namespaces.values.flatMap { namespace in
            let chains = (namespace.chains ?? []) + namespace.accounts.map(\.blockchain)
            return chains
                .filter { $0.namespace == WalletConnectChain.eth.namespace }
                .map(\.absoluteString)
        })
        guard !evmChainIds.isEmpty else {
            return nil
        }
        return Dictionary(
            uniqueKeysWithValues: evmChainIds.sorted().map {
                ($0, #"{"atomic":{"status":"unsupported"}}"#)
            }
        )
    }
}

private extension WalletConnectSessionNamespaceBuilder {
    func addNamespaces(
        _ namespaces: [String: ProposalNamespace],
        required: Bool,
        accountsByBlockchain: [Blockchain: [WalletConnectUtils.Account]],
        result: inout [String: SessionNamespace]
    ) throws(WalletConnectSessionApprovalError) {
        for (key, proposalNamespace) in namespaces {
            let requestedChains = requestedBlockchains(namespaceKey: key, namespace: proposalNamespace)
            let supportedChains = requestedChains.filter { accountsByBlockchain[$0]?.isEmpty == false }
            let unsupportedChains = requestedChains.filter { accountsByBlockchain[$0]?.isEmpty != false }
            let supportedMethods = supportedMethods(namespaceKey: key, chains: requestedChains)
            let supportedEvents = supportedEvents(namespaceKey: key, chains: requestedChains)
            let unsupportedMethods = proposalNamespace.methods.subtracting(supportedMethods)
            let unsupportedEvents = proposalNamespace.events.subtracting(supportedEvents)

            if required {
                if !unsupportedChains.isEmpty {
                    throw .unsupportedRequiredChains(unsupportedChains.map(\.absoluteString))
                }
                if !unsupportedMethods.isEmpty || !unsupportedEvents.isEmpty {
                    throw .unsupportedRequiredMethods(unsupportedMethods.union(unsupportedEvents).sorted())
                }
            }

            let approvedMethods = proposalNamespace.methods.intersection(supportedMethods)
            let approvedEvents = proposalNamespace.events.intersection(supportedEvents)
            let approvedAccounts = supportedChains.flatMap { accountsByBlockchain[$0] ?? [] }

            guard !supportedChains.isEmpty, !approvedAccounts.isEmpty else {
                continue
            }
            guard !approvedMethods.isEmpty else {
                continue
            }

            let sessionNamespace = SessionNamespace(
                chains: supportedChains,
                accounts: approvedAccounts,
                methods: approvedMethods,
                events: approvedEvents
            )

            let resultKey = resultNamespaceKey(namespaceKey: key, namespace: proposalNamespace)
            if var existing = result[resultKey] {
                existing.chains = Array(Set((existing.chains ?? []) + supportedChains))
                existing.accounts = Array(Set(existing.accounts + approvedAccounts))
                existing.methods.formUnion(approvedMethods)
                existing.events.formUnion(approvedEvents)
                result[resultKey] = existing
            } else {
                result[resultKey] = sessionNamespace
            }
        }
    }

    func chains(namespaceKey: String, namespace: ProposalNamespace) -> [WalletConnectChain] {
        requestedBlockchains(namespaceKey: namespaceKey, namespace: namespace)
            .compactMap { WalletConnectChain(caip2: $0.absoluteString) }
    }

    func requestedBlockchains(namespaceKey: String, namespace: ProposalNamespace) -> [Blockchain] {
        if let chains = namespace.chains {
            return chains
        }
        if let blockchain = Blockchain(namespaceKey) {
            return [blockchain]
        }
        guard let chain = defaultChain(namespaceKey: namespaceKey),
              let blockchain = Blockchain(chain.caip2)
        else {
            return []
        }
        return [blockchain]
    }

    func methods(
        _ values: Set<String>,
        namespaceKey: String,
        namespace: ProposalNamespace
    ) -> Set<WalletConnectMethod> {
        let chains = chains(namespaceKey: namespaceKey, namespace: namespace).compactMap { Blockchain($0.caip2) }
        let supportedMethods = supportedMethods(namespaceKey: namespaceKey, chains: chains)
        return Set(values.intersection(supportedMethods).compactMap(WalletConnectMethod.init(rawValue:)))
    }

    func supportedMethods(namespaceKey: String, chains: [Blockchain]) -> Set<String> {
        let namespaces = chains.isEmpty
            ? [namespaceKey]
            : chains.map(\.namespace)
        return Set(namespaces.flatMap {
            WalletConnectMethod.supportedMethods(namespace: $0).map(\.rawValue)
        })
    }

    func supportedEvents(namespaceKey: String, chains: [Blockchain]) -> Set<String> {
        let namespaces = chains.isEmpty
            ? [namespaceKey]
            : chains.map(\.namespace)
        return Set(namespaces.flatMap { namespace -> [String] in
            switch namespace.components(separatedBy: ":").first {
            case "eip155":
                return [
                    "accountsChanged",
                    "chainChanged",
                    "connect",
                    "disconnect",
                    "message",
                ]
            default:
                return []
            }
        })
    }

    func resultNamespaceKey(
        namespaceKey: String,
        namespace: ProposalNamespace
    ) -> String {
        if let blockchain = requestedBlockchains(namespaceKey: namespaceKey, namespace: namespace).first {
            return blockchain.namespace
        }
        return namespaceKey
    }

    func defaultChain(namespaceKey: String) -> WalletConnectChain? {
        let namespace = namespaceKey.components(separatedBy: ":").first?.lowercased()
        switch namespace {
        case WalletConnectChain.ton.namespace:
            return .ton
        default:
            return nil
        }
    }

    func walletConnectTONStateInit(wallet: Wallet) throws -> String {
        let stateInit = try wallet.stateInit
        let builder = Builder()
        try stateInit.storeTo(builder: builder)
        let cell = try builder.asCell()
        return try cell.toBoc().base64EncodedString()
    }
}
