@testable import KeeperCore
import XCTest

final class EarnFeaturedVaultTests: XCTestCase {
    func testPlainAddressIsAVaultIdentifier() throws {
        let vault = try XCTUnwrap(EarnFeaturedVault(network: "mainnet", vaultId: address))

        XCTAssertEqual(vault.network, "mainnet")
        XCTAssertEqual(vault.vaultId, address)
    }

    func testUniqueDescriptorStaysInTheIdentifier() throws {
        let vault = try XCTUnwrap(EarnFeaturedVault(network: "base", vaultId: "\(address)-usdc-v2"))

        XCTAssertEqual(vault.vaultId, "\(address)-usdc-v2")
    }

    func testIdentifierCaseIsPreserved() throws {
        let checksummed = "0xAbCdEf1234567890aBcDeF1234567890AbCdEf12"
        let vault = try XCTUnwrap(EarnFeaturedVault(network: "base", vaultId: checksummed))

        XCTAssertEqual(vault.vaultId, checksummed)
    }

    func testSurroundingWhitespaceIsTrimmed() throws {
        let vault = try XCTUnwrap(EarnFeaturedVault(network: "  base  ", vaultId: "  \(address)  "))

        XCTAssertEqual(vault.network, "base")
        XCTAssertEqual(vault.vaultId, address)
    }

    func testMalformedIdentifiersAreRejected() {
        XCTAssertNil(EarnFeaturedVault(network: "base", vaultId: ""))
        XCTAssertNil(EarnFeaturedVault(network: "base", vaultId: "0x1234"))
        XCTAssertNil(EarnFeaturedVault(network: "base", vaultId: String(address.dropFirst(2))))
        XCTAssertNil(EarnFeaturedVault(network: "base", vaultId: "0xzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"))
        XCTAssertNil(EarnFeaturedVault(network: "base", vaultId: "\(address)-"))
        XCTAssertNil(EarnFeaturedVault(network: "", vaultId: address))
        XCTAssertNil(EarnFeaturedVault(network: "   ", vaultId: address))
    }
}

private extension EarnFeaturedVaultTests {
    var address: String {
        "0x1234567890abcdef1234567890abcdef12345678"
    }
}
