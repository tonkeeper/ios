@testable import KeeperCore
import TonSwift
import XCTest

final class RecipientResolverTests: XCTestCase {
    func test_resolverRecipient_resolvesTonAddressAsLegacyTonRecipient() async throws {
        let address = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
        let resolver = makeResolver()

        let recipient = try await resolver.resolverRecipient(
            string: address,
            network: .mainnet
        )

        guard case let .ton(tonRecipient) = recipient else {
            XCTFail("Expected TON recipient")
            return
        }
        XCTAssertEqual(tonRecipient.recipientAddress.addressString, address)
    }

    func test_resolverRecipient_resolvesTronAddressAsLegacyTronRecipient() async throws {
        let address = "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
        let resolver = makeResolver()

        let recipient = try await resolver.resolverRecipient(
            string: address,
            network: .mainnet
        )

        guard case let .tron(tronRecipient) = recipient else {
            XCTFail("Expected TRON recipient")
            return
        }
        XCTAssertEqual(tronRecipient.base58, address)
    }

    func test_resolverRecipient_rejectsInvalidAddress() async {
        let input = "not-an-address"
        let resolver = makeResolver()

        await assertFailedResolve(input) {
            _ = try await resolver.resolverRecipient(string: input, network: .mainnet)
        }
    }

    func test_resolverRecipient_doesNotResolveNonLegacyChainAddresses() async {
        let testCases: [(chain: MultichainChain, address: String)] = [
            (.eth, "0x000000000000000000000000000000000000dead"),
            (.base, "0x000000000000000000000000000000000000dead"),
            (.bsc, "0x000000000000000000000000000000000000dead"),
            (.arb, "0x000000000000000000000000000000000000dead"),
            (.btc, "1BoatSLRHtKNngkdXEeobR76b53LETtpyT"),
        ]
        let resolver = makeResolver()

        for testCase in testCases {
            await assertFailedResolve(testCase.address, message: "\(testCase.chain)") {
                _ = try await resolver.resolverRecipient(
                    string: testCase.address,
                    network: .mainnet
                )
            }
        }
    }
}

private extension RecipientResolverTests {
    func makeResolver() -> RecipientResolverImplementation {
        RecipientResolverImplementation(
            dnsService: DNSServiceFake(),
            accountService: AccountServiceFake()
        )
    }

    func assertFailedResolve(
        _ expectedString: String,
        message: String = "",
        _ block: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await block()
            XCTFail("Expected failedResolve. \(message)", file: file, line: line)
        } catch let error as RecipientResolverImplementation.Error {
            guard case let .failedResolve(string) = error else {
                XCTFail("Expected failedResolve, got \(error). \(message)", file: file, line: line)
                return
            }
            XCTAssertEqual(string, expectedString, message, file: file, line: line)
        } catch {
            XCTFail("Expected failedResolve, got \(error). \(message)", file: file, line: line)
        }
    }
}

private enum RecipientResolverTestError: Error {
    case failed
}

private final class DNSServiceFake: DNSService {
    func resolveDomainName(
        _ domainName: String,
        addTonPostfix: Bool,
        network: Network
    ) async throws -> Domain {
        throw RecipientResolverTestError.failed
    }

    func loadDomainExpirationDate(
        _ domainName: String,
        network: Network
    ) async throws -> Date? {
        throw RecipientResolverTestError.failed
    }
}

private final class AccountServiceFake: AccountService {
    func loadAccount(
        network: Network,
        address: Address
    ) async throws -> Account {
        Account(
            address: address,
            balance: 0,
            status: "active",
            name: nil,
            icon: nil,
            isSuspended: nil,
            isWallet: true,
            isScam: false,
            isMemoRequired: false
        )
    }

    func loadAccount(
        network: Network,
        domain: String
    ) async throws -> Account {
        throw RecipientResolverTestError.failed
    }
}
