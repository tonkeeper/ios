import Foundation
import TonSwift

public protocol RecipientResolver {
    func resolverRecipient(
        string: String,
        network: Network
    ) async throws -> LegacyRecipient
    func resolverTonRecipient(string: String, network: Network) async throws -> TonRecipient
}

struct RecipientResolverImplementation: RecipientResolver {
    enum Error: Swift.Error {
        case failedResolve(string: String)
        case incorrectNet(sender: Network, recipient: Network)
    }

    private let dnsService: DNSService
    private let accountService: AccountService

    init(
        dnsService: DNSService,
        accountService: AccountService
    ) {
        self.dnsService = dnsService
        self.accountService = accountService
    }

    func resolverRecipient(
        string: String,
        network: Network
    ) async throws -> LegacyRecipient {
        if let tronRecipient = resolveTronRecipient(string: string) {
            return .tron(tronRecipient)
        }

        return try .ton(await resolverTonRecipient(string: string, network: network))
    }

    func resolverTonRecipient(string: String, network: Network) async throws -> TonRecipient {
        if let friendlyAddress = try? FriendlyAddress(string: string) {
            guard network.matchesTonAddress(friendlyAddress) else {
                throw Error.incorrectNet(
                    sender: network,
                    recipient: friendlyAddress.isTestOnly ? .testnet : .mainnet
                )
            }

            let account = try await getAccount(
                for: friendlyAddress.address,
                network: network
            )

            return TonRecipient(
                recipientAddress: .friendly(friendlyAddress),
                isMemoRequired: account.isMemoRequired == true,
                isScam: account.isScam == true
            )
        } else if let address = try? Address.parse(string) {
            let account = try await getAccount(
                for: address,
                network: network
            )

            return TonRecipient(
                recipientAddress: .raw(address),
                isMemoRequired: account.isMemoRequired == true,
                isScam: account.isScam == true
            )
        } else if let account = try? await getAccount(
            for: string,
            network: network
        ) {
            let domain = Domain(domain: string, friendlyAddress: account.address.toFriendly(bounceable: !account.isWallet))

            return TonRecipient(
                recipientAddress: .domain(domain),
                isMemoRequired: account.isMemoRequired == true,
                isScam: account.isScam == true
            )
        } else {
            throw Error.failedResolve(string: string)
        }
    }

    private func resolveTronRecipient(string: String) -> TronRecipient? {
        try? TronRecipient(address: string)
    }

    private func getAccount(for address: Address, network: Network) async throws -> Account {
        try await accountService.loadAccount(network: network, address: address)
    }

    private func getAccount(for domain: String, network: Network) async throws -> Account {
        try await accountService.loadAccount(network: network, domain: domain)
    }
}
