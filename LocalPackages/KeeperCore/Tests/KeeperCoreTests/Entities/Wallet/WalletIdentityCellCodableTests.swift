@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import XCTest

final class WalletIdentityCellCodableTests: XCTestCase {
    func test_wallet_identitty_coding() throws {
        // GIVEN
        let publicKey = try TonSwift.PublicKey(data: XCTUnwrap(Data(strictHex: "5754865e86d0ade1199301bbb0319a25ed6b129c4b0a57f28f62449b3df9c522")))
        let walletKind = WalletKind.Regular(publicKey, .v4R2)
        let walletIdentity = WalletIdentity(network: .testnet, kind: walletKind)
        let builder = Builder()

        // WHEN
        try walletIdentity.storeTo(builder: builder)
        let slice = Slice(bits: builder.bitstring())
        let decodedWalletIdentity: WalletIdentity = try slice.loadType()

        // THEN
        XCTAssertEqual(decodedWalletIdentity.network, .testnet)
        guard case let .Regular(decodedPublicKey, revision) = decodedWalletIdentity.kind,
              decodedPublicKey.data == publicKey.data,
              revision == revision
        else {
            XCTFail()
            return
        }
    }
}

// WalletKind

extension WalletIdentityCellCodableTests {
    func test_wallet_kind_regular_coding() throws {
        // GIVEN
        let publicKey = try TonSwift.PublicKey(data: XCTUnwrap(Data(strictHex: "5754865e86d0ade1199301bbb0319a25ed6b129c4b0a57f28f62449b3df9c522")))
        let walletKind = WalletKind.Regular(publicKey, .v4R2)
        let builder = Builder()

        // WHEN
        try walletKind.storeTo(builder: builder)
        let slice = Slice(bits: builder.bitstring())
        let decodedWalletKind: WalletKind = try slice.loadType()

        // THEN
        guard case let .Regular(decodedPublicKey, revision) = decodedWalletKind,
              decodedPublicKey.data == publicKey.data,
              revision == revision
        else {
            XCTFail()
            return
        }
    }

    func test_wallet_kind_lockup_coding() throws {
        // GIVEN
        let lockupConfig = LockupConfig()
        let publicKey = try TonSwift.PublicKey(data: XCTUnwrap(Data(strictHex: "5754865e86d0ade1199301bbb0319a25ed6b129c4b0a57f28f62449b3df9c522")))
        let walletKind = WalletKind.Lockup(publicKey, lockupConfig)
        let builder = Builder()

        // WHEN
        try walletKind.storeTo(builder: builder)
        let slice = Slice(bits: builder.bitstring())
        let decodedWalletKind: WalletKind = try slice.loadType()

        // THEN
        guard case let .Lockup(decodedPublicKey, decodedLockupConfig) = decodedWalletKind,
              decodedPublicKey.data == publicKey.data,
              decodedLockupConfig == lockupConfig
        else {
            XCTFail()
            return
        }
    }

    func test_wallet_kind_watchonly_coding() throws {
        // GIVEN
        let address = Address.mock(workchain: 0, seed: "testResolvableAddressResolvedCoding")
        let resolvableAddress = ResolvableAddress.Resolved(address)
        let walletKind = WalletKind.Watchonly(resolvableAddress)
        let builder = Builder()

        // WHEN
        try walletKind.storeTo(builder: builder)
        let slice = Slice(bits: builder.bitstring())
        let decodedWalletKind: WalletKind = try slice.loadType()

        // THEN
        guard case let .Watchonly(decodedResolvableAddress, decodedContractVersion) = decodedWalletKind,
              case let .Resolved(decodedAddress) = decodedResolvableAddress,
              decodedAddress == address,
              decodedContractVersion == nil
        else {
            XCTFail()
            return
        }
    }

    func test_wallet_kind_watchonly_without_version_keeps_the_stored_layout() throws {
        let resolvableAddress = ResolvableAddress.Resolved(
            Address.mock(workchain: 0, seed: "testWatchonlyStoredLayout")
        )
        let storedLayout = Builder()
        try storedLayout.store(uint: 2, bits: 5)
        try resolvableAddress.storeTo(builder: storedLayout)

        let encoded = Builder()
        try WalletKind.Watchonly(resolvableAddress).storeTo(builder: encoded)
        let decoded: WalletKind = try Slice(bits: storedLayout.bitstring()).loadType()

        XCTAssertEqual(encoded.bitstring().toBinary(), storedLayout.bitstring().toBinary())
        XCTAssertEqual(decoded, .Watchonly(resolvableAddress, nil))
    }

    func test_wallet_kind_watchonly_with_version_coding() throws {
        let resolvableAddress = ResolvableAddress.Domain(
            "wallet.ton",
            Address.mock(workchain: 0, seed: "testWatchonlyVersionCoding")
        )
        let identity = WalletIdentity(network: .mainnet, kind: .Watchonly(resolvableAddress, .walletTg))

        let builder = Builder()
        try identity.kind.storeTo(builder: builder)
        let decodedKind: WalletKind = try Slice(bits: builder.bitstring()).loadType()
        let decodedIdentity = try JSONDecoder().decode(
            [WalletIdentity].self,
            from: JSONEncoder().encode([identity])
        )

        XCTAssertEqual(decodedKind, .Watchonly(resolvableAddress, .walletTg))
        XCTAssertEqual(decodedIdentity, [identity])
    }

    func test_wallet_kind_watchonly_version_is_part_of_the_identity() throws {
        let resolvableAddress = ResolvableAddress.Resolved(
            Address.mock(workchain: 0, seed: "testWatchonlyVersionIdentity")
        )
        let plain = WalletIdentity(network: .mainnet, kind: .Watchonly(resolvableAddress))
        let telegram = WalletIdentity(network: .mainnet, kind: .Watchonly(resolvableAddress, .walletTg))

        XCTAssertNotEqual(plain, telegram)
        XCTAssertNotEqual(try plain.identifier().string, try telegram.identifier().string)
    }

    func test_wallet_kind_external_coding() throws {
        // GIVEN
        let publicKey = try TonSwift.PublicKey(data: XCTUnwrap(Data(strictHex: "5754865e86d0ade1199301bbb0319a25ed6b129c4b0a57f28f62449b3df9c522")))
        let walletKind = WalletKind.Signer(publicKey, .v4R2)
        let builder = Builder()

        // WHEN
        try walletKind.storeTo(builder: builder)
        let slice = Slice(bits: builder.bitstring())
        let decodedWalletKind: WalletKind = try slice.loadType()

        // THEN
        guard case let .Signer(decodedPublicKey, revision) = decodedWalletKind,
              decodedPublicKey.data == publicKey.data,
              revision == revision
        else {
            XCTFail()
            return
        }
    }
}

// ResolvableAddress

extension WalletIdentityCellCodableTests {
    func testResolvableAddressResolvedCoding() throws {
        // GIVEN
        let address = Address.mock(workchain: 0, seed: "testResolvableAddressResolvedCoding")
        let resolvedAddress = ResolvableAddress.Resolved(address)
        let builder = Builder()

        // WHEN
        try resolvedAddress.storeTo(builder: builder)
        let slice = Slice(bits: builder.bitstring())
        let decodedResolvedAddress: ResolvableAddress = try slice.loadType()

        // THEN
        XCTAssertEqual(decodedResolvedAddress, resolvedAddress)
    }

    func testResolvableAddressDomainCoding() throws {
        // GIVEN
        let domain = "it's test domain even with emoji🚘👯‍♂️. let's try to encode and decode it"
        let address = Address.mock(workchain: 0, seed: "testResolvableAddressResolvedCoding")
        let resolvedAddress = ResolvableAddress.Domain(domain, address)
        let builder = Builder()

        // WHEN
        try resolvedAddress.storeTo(builder: builder)
        let slice = Slice(bits: builder.bitstring())
        let decodedResolvedAddress: ResolvableAddress = try slice.loadType()

        // THEN
        XCTAssertEqual(decodedResolvedAddress, resolvedAddress)
    }
}

// Network

extension WalletIdentityCellCodableTests {
    func testNetworkMainnetCoding() throws {
        // GIVEN
        let network = Network.mainnet
        let builder = Builder()

        // WHEN
        try network.storeTo(builder: builder)
        let slice = Slice(bits: builder.bitstring())
        let decodedNetwork: Network = try slice.loadType()

        // THEN
        XCTAssertEqual(decodedNetwork, network)
    }

    func testNetworkTestnetCoding() throws {
        // GIVEN
        let network = Network.testnet
        let builder = Builder()

        // WHEN
        try network.storeTo(builder: builder)
        let slice = Slice(bits: builder.bitstring())
        let decodedNetwork: Network = try slice.loadType()

        // THEN
        XCTAssertEqual(decodedNetwork, network)
    }
}
