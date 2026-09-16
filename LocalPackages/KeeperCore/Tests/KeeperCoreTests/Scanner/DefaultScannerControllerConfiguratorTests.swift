@testable import KeeperCore
import XCTest

final class DefaultScannerControllerConfiguratorTests: XCTestCase {
    func testHandleQRCodeCreatesTransferDeeplinkForPlainTonAddress() throws {
        let address = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"

        let deeplink = try configurator.handleQRCode(address)

        XCTAssertEqual(deeplink, transferDeeplink(recipient: address, chains: [.ton]))
    }

    func testHandleQRCodeCreatesTransferDeeplinkForPlainTronAddress() throws {
        let address = "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"

        let deeplink = try configurator.handleQRCode(address)

        XCTAssertEqual(deeplink, transferDeeplink(recipient: address, chains: [.tron]))
    }

    func testHandleQRCodeCreatesTransferDeeplinkForPlainBitcoinAddress() throws {
        let address = "1BoatSLRHtKNngkdXEeobR76b53LETtpyT"

        let deeplink = try configurator.handleQRCode(address)

        XCTAssertEqual(deeplink, transferDeeplink(recipient: address, chains: [.btc]))
    }

    func testHandleQRCodeCreatesTransferDeeplinkForPlainEVMAddress() throws {
        let address = "0x000000000000000000000000000000000000dead"

        let deeplink = try configurator.handleQRCode(address)

        guard case let .transfer(.multichainSendTransfer(candidates)) = deeplink else {
            return XCTFail("Expected a multichain send transfer")
        }
        XCTAssertEqual(candidates.address, address)
        XCTAssertEqual(Set(candidates.chains), [.eth, .base, .arb, .bsc])
    }

    func testHandleQRCodeRejectsSchemePrefixedPayloads() {
        let evmAddress = "0x000000000000000000000000000000000000dead"
        let bitcoinAddress = "1BoatSLRHtKNngkdXEeobR76b53LETtpyT"
        let payloads = [
            "bitcoin:\(bitcoinAddress)?amount=0.001",
            "btc:\(bitcoinAddress)",
            "base:\(evmAddress)",
            "arbitrum:\(evmAddress)",
            "bsc:\(evmAddress)",
        ]

        for payload in payloads {
            XCTAssertThrowsError(
                try configurator.handleQRCode(payload),
                payload
            )
        }
    }

    func testHandleQRCodeCreatesEvmTransferForErc681Payloads() throws {
        let evmAddress = "0x000000000000000000000000000000000000dead"
        let payloads = [
            "ethereum:\(evmAddress)",
            "ethereum:pay-\(evmAddress)@8453",
            "eth:\(evmAddress)",
        ]

        for payload in payloads {
            let deeplink = try configurator.handleQRCode(payload)

            guard case let .transfer(.evmSendTransfer(transfer)) = deeplink else {
                return XCTFail("Expected an EVM send transfer for \(payload)")
            }
            XCTAssertEqual(transfer.recipient, evmAddress)
            XCTAssertEqual(transfer.asset, .native)
        }
    }

    func testLegacyHandleQRCodeCreatesSendTransferForPlainTonAddress() throws {
        let address = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"

        let deeplink = try legacyConfigurator.handleQRCode(address)

        XCTAssertEqual(deeplink, legacySendTransferDeeplink(recipient: address))
    }

    func testLegacyHandleQRCodeCreatesSendTransferForPlainTronAddress() throws {
        let address = "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"

        let deeplink = try legacyConfigurator.handleQRCode(address)

        XCTAssertEqual(deeplink, legacySendTransferDeeplink(recipient: address))
    }

    func testLegacyHandleQRCodeRejectsPlainEVMAddress() {
        let address = "0x000000000000000000000000000000000000dead"

        XCTAssertThrowsError(try legacyConfigurator.handleQRCode(address))
    }

    func testLegacyHandleQRCodeRejectsPlainBitcoinAddress() {
        let address = "1BoatSLRHtKNngkdXEeobR76b53LETtpyT"

        XCTAssertThrowsError(try legacyConfigurator.handleQRCode(address))
    }

    private var configurator: DefaultScannerControllerConfigurator {
        makeConfigurator(isMultichainEnabled: true)
    }

    private var legacyConfigurator: DefaultScannerControllerConfigurator {
        makeConfigurator(isMultichainEnabled: false)
    }

    private func makeConfigurator(isMultichainEnabled: Bool) -> DefaultScannerControllerConfigurator {
        DefaultScannerControllerConfigurator(
            extensions: [],
            deeplinkParser: DeeplinkParser(
                walletConnectDeeplinkValidator: WalletConnectDeeplinkValidatorImplementation()
            ),
            isMultichainEnabled: isMultichainEnabled
        )
    }

    private func transferDeeplink(recipient: String, chains: [MultichainChain]) -> Deeplink {
        .transfer(
            .multichainSendTransfer(
                MultichainRecipientCandidates(address: recipient, chains: chains)
            )
        )
    }

    private func legacySendTransferDeeplink(recipient: String) -> Deeplink {
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
