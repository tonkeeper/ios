@testable import App
import XCTest

final class URLEarnVaultTests: XCTestCase {
    func test_vaultRouteNamesItsVaultByAssetId() throws {
        let url = try XCTUnwrap(URL(string: "https://vaults.fyi"))
            .appendingEarnVaultPath(network: "mainnet", vaultId: "0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a")

        XCTAssertEqual(url.earnVaultAssetId, "eth/mainnet/erc20/0x23878914efe38d27c4d67ab83ed1b93a74d4086a")
    }

    func test_vaultRouteUnderABasePathNamesItsVault() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/app/earn/base/0xABC?tab=deposit"))

        XCTAssertEqual(url.earnVaultAssetId, "base/mainnet/erc20/0xabc")
    }

    func test_bscVaultTakesTheBnbChain() throws {
        let url = try XCTUnwrap(URL(string: "https://vaults.fyi/earn/bsc/0xFD5840Cd36d94D7229439859C0112a4185BC0255"))

        XCTAssertEqual(url.earnVaultAssetId, "bnb/mainnet/erc20/0xfd5840cd36d94d7229439859c0112a4185bc0255")
    }

    func test_vaultOnANetworkTheWalletDoesNotHaveHasNoId() throws {
        XCTAssertNil(try XCTUnwrap(URL(string: "https://vaults.fyi/earn/optimism/0xabc")).earnVaultAssetId)
    }

    func test_catalogIsNotAVaultRoute() throws {
        XCTAssertNil(try XCTUnwrap(URL(string: "https://vaults.fyi")).earnVaultAssetId)
        XCTAssertNil(try XCTUnwrap(URL(string: "https://vaults.fyi/earn")).earnVaultAssetId)
        XCTAssertNil(try XCTUnwrap(URL(string: "https://vaults.fyi/earn/mainnet")).earnVaultAssetId)
    }
}
