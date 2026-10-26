@testable import KeeperCore
import XCTest

final class RampRecipientScannerControllerConfiguratorTests: XCTestCase {
    func testExchangeDepositAddressBecomesArbitrumRecipient() throws {
        let address = "0x3dA56A7b93ba93ECe9E9a9DE4C76079010315E59"
        let configurator = RampRecipientScannerControllerConfigurator(
            assetId: "arb/mainnet/erc20/0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9",
            networkName: "Arbitrum"
        )

        XCTAssertEqual(try configurator.handleQRCode(address), transferDeeplink(recipient: address))
    }

    func testAddressOfAnotherNetworkIsRejected() {
        let configurator = RampRecipientScannerControllerConfigurator(
            assetId: "op/mainnet/erc20/0x0b2c639c533813f4aa9d7837caf62653d097ff85",
            networkName: "Optimism"
        )

        XCTAssertThrowsError(try configurator.handleQRCode("TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t")) { error in
            XCTAssertEqual(
                error as? RampRecipientScannerControllerConfigurator.Error,
                .invalidAddress(networkName: "Optimism")
            )
        }
    }

    func testUnknownNetworkKeepsScannedText() throws {
        let configurator = RampRecipientScannerControllerConfigurator(
            assetId: "xrp/mainnet/coin",
            networkName: "Ripple"
        )

        XCTAssertEqual(
            try configurator.handleQRCode(" rEb8TK3gBgk5auZkwc6sHnwrGVJH8DuaLh\n"),
            transferDeeplink(recipient: "rEb8TK3gBgk5auZkwc6sHnwrGVJH8DuaLh")
        )
    }

    private func transferDeeplink(recipient: String) -> Deeplink {
        .transfer(
            .sendTransfer(
                Deeplink.TransferData(
                    recipient: recipient,
                    amount: nil,
                    comment: nil,
                    jettonAddress: nil,
                    assetId: nil,
                    expirationTimestamp: nil,
                    successReturn: nil
                )
            )
        )
    }
}
