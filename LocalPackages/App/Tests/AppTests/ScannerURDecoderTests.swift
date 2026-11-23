@testable import App
@testable import KeeperCore
import TKCore
import TKUIKit
import TonSwift
import URKit
import XCTest

final class ScannerURDecoderTests: XCTestCase {
    func testEachConfiguratorCanDecodeANewURAfterACompletedRejectedResult() throws {
        let parser = DeeplinkParser(walletConnectDeeplinkValidator: WalletConnectDeeplinkValidatorImplementation())
        let configurators: [any ScannerControllerConfigurator] = [
            KeystoneScannerControllerConfigurator(deeplinkParser: parser),
            SignerScannerControllerConfigurator(deeplinkParser: parser),
            KeystoneSignControllerConfigurator(deeplinkParser: parser),
            SignerSignControllerConfigurator(deeplinkParser: parser),
            DefaultScannerControllerConfigurator(extensions: [], deeplinkParser: parser, isMultichainEnabled: false),
        ]
        let rejected = try UR(type: "bytes", untaggedCBOR: Data([1]))
        let next = try UR(type: "crypto-hdkey", untaggedCBOR: Data([2]))

        for configurator in configurators {
            XCTAssertEqual(try configurator.handleQRCodeUR(rejected.string), rejected)
            XCTAssertEqual(try configurator.handleQRCodeUR(next.string), next)
        }
    }

    func testMultipartAssemblySurvivesIncompleteResultsAndResetsAfterCompletion() throws {
        let decoder = ScannerURDecoder()
        let ur = try UR(type: "bytes", untaggedCBOR: Data(0 ... 255))
        let encoder = UREncoder(ur, maxFragmentLen: 30)
        var decoded: UR?

        for _ in 0 ..< encoder.seqLen {
            do {
                decoded = try decoder.decode(encoder.nextPart())
            } catch KeeperCore.URError.noResult {
                continue
            }
        }

        XCTAssertEqual(decoded, ur)
        let next = try UR(type: "crypto-hdkey", untaggedCBOR: Data([2]))
        XCTAssertEqual(try decoder.decode(next.string), next)
    }

    func testUppercaseSingleAndMultipartQRsDecode() throws {
        let decoder = ScannerURDecoder()
        let single = try UR(type: "crypto-hdkey", untaggedCBOR: Data([1]))
        XCTAssertEqual(try decoder.decode(single.string.uppercased()), single)

        let multipart = try UR(type: "bytes", untaggedCBOR: Data(0 ... 255))
        let encoder = UREncoder(multipart, maxFragmentLen: 30)
        var result: UR?
        for _ in 0 ..< encoder.seqLen {
            do {
                result = try decoder.decode(encoder.nextPart().uppercased())
            } catch KeeperCore.URError.noResult {
                continue
            }
        }
        XCTAssertEqual(result, multipart)
    }

    func testMalformedPartsKeepTheExistingURKitNoResultBehavior() {
        for part in ["ur:bytes/not-bytewords", "ur:bytes/1-2/not-bytewords", "ur:bytes/1-2/extra/path", "ur:bytes/", "invalid"] {
            let originalDecoder = URDecoder()
            XCTAssertFalse(originalDecoder.receivePart(part))
            XCTAssertNil(originalDecoder.result)
            XCTAssertThrowsError(try ScannerURDecoder().decode(part)) { error in
                guard case KeeperCore.URError.noResult = error else {
                    return XCTFail("Expected noResult for \(part), got \(error)")
                }
            }
        }
    }

    func testKeystoneHandlerRejectsMissingKeyDataAndAcceptsTheNextValidKey() throws {
        let output = ScannerOutputProbe()
        let viewModel = KeystoneImportScanViewModelImplementation(urlOpener: NoURLOpener(), scannerViewModuleOutput: output)
        var deliveries = 0
        viewModel.didScanQRCode = { _, _, _, _ in deliveries += 1 }
        viewModel.viewDidLoad()
        let handler = try XCTUnwrap(output.didScanUR)
        let missingKey = try UR(type: "crypto-hdkey", cbor: CBOR(Data([0xA0])))
        let validKey = try UR(type: "crypto-hdkey", cbor: CBOR(Data([0xA1, 0x03, 0x58, 0x20] + Array(repeating: 1, count: 32))))

        XCTAssertFalse(try handler(missingKey))
        XCTAssertEqual(deliveries, 0)
        XCTAssertTrue(try handler(validKey))
        XCTAssertEqual(deliveries, 1)
    }

    func testKeystoneHandlerRejectsDeliveryWithoutAConsumer() throws {
        let output = ScannerOutputProbe()
        let viewModel = KeystoneImportScanViewModelImplementation(urlOpener: NoURLOpener(), scannerViewModuleOutput: output)
        viewModel.viewDidLoad()
        let ur = try UR(type: "bytes", untaggedCBOR: Data([1]))

        XCTAssertFalse(try XCTUnwrap(output.didScanUR)(ur))
    }

    func testDifferentMultipartQRReplacesAnIncompleteMessageWithTheSameTypeAndLength() throws {
        let decoder = ScannerURDecoder()
        let old = try UR(type: "bytes", untaggedCBOR: Data(repeating: 1, count: 256))
        let oldEncoder = UREncoder(old, maxFragmentLen: 30)
        XCTAssertThrowsError(try decoder.decode(oldEncoder.nextPart()))
        let next = try UR(type: "bytes", untaggedCBOR: Data(repeating: 2, count: 256))
        let nextEncoder = UREncoder(next, maxFragmentLen: 30)

        XCTAssertEqual(try decodeMessage(nextEncoder, with: decoder), next)
    }

    func testSinglePartURReplacesAnIncompleteMessageWithADifferentType() throws {
        let decoder = ScannerURDecoder()
        let old = try UR(type: "bytes", untaggedCBOR: Data(repeating: 1, count: 256))
        XCTAssertThrowsError(try decoder.decode(UREncoder(old, maxFragmentLen: 30).nextPart()))
        let next = try UR(type: "crypto-hdkey", untaggedCBOR: Data([2]))

        XCTAssertEqual(try decoder.decode(next.string), next)
    }

    func testControllerResetDiscardsPartsFromThePreviousCameraRun() throws {
        let parser = DeeplinkParser(walletConnectDeeplinkValidator: WalletConnectDeeplinkValidatorImplementation())
        let controller = ScannerController(configurator: KeystoneScannerControllerConfigurator(deeplinkParser: parser))
        let ur = try UR(type: "bytes", untaggedCBOR: Data(repeating: 1, count: 256))
        let encoder = UREncoder(ur, maxFragmentLen: 30)
        let first = encoder.nextPart()
        XCTAssertThrowsError(try controller.handleScannedQRCodeUR(first))

        controller.resetURDecoding()

        for _ in 1 ..< encoder.seqLen {
            XCTAssertThrowsError(try controller.handleScannedQRCodeUR(encoder.nextPart()))
        }
        XCTAssertEqual(try controller.handleScannedQRCodeUR(first), ur)
    }

    func testDuplicateFragmentDoesNotDiscardTheOtherCollectedParts() throws {
        let decoder = ScannerURDecoder()
        let ur = try UR(type: "bytes", untaggedCBOR: Data(0 ... 255))
        let encoder = UREncoder(ur, maxFragmentLen: 30)
        let first = encoder.nextPart()
        XCTAssertThrowsError(try decoder.decode(first))
        XCTAssertThrowsError(try decoder.decode(first))

        XCTAssertEqual(try decodeMessage(encoder, with: decoder), ur)
    }

    func testGalleryFragmentCannotJoinOrClearTheCameraMessage() throws {
        let cameraDecoder = ScannerURDecoder()
        let ur = try UR(type: "bytes", untaggedCBOR: Data(0 ... 255))
        let encoder = UREncoder(ur, maxFragmentLen: 30)
        let first = encoder.nextPart()
        XCTAssertThrowsError(try cameraDecoder.decode(first))
        let galleryPart = encoder.nextPart()

        XCTAssertThrowsError(try ScannerURDecoder().decode(galleryPart))
        XCTAssertThrowsError(try cameraDecoder.decode(galleryPart))
        XCTAssertEqual(try decodeMessage(encoder, with: cameraDecoder), ur)
    }

    @MainActor
    func testKeystoneSigningRejectsAnUnrelatedURBeforeDeliveringAValidSignature() throws {
        let output = ScannerOutputProbe()
        let transaction = try UR(type: "bytes", untaggedCBOR: Data([1]))
        let wallet = Wallet(
            id: "scanner-sign-test",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: WalletMetaData(label: "Test", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
        let viewModel = KeystoneSignViewModelImplementation(
            keystoneSignController: KeystoneSignController(transaction: transaction, wallet: wallet),
            qrCodeGenerator: NoQRCodeGenerator(),
            scannerOutput: output
        )
        var deliveries = 0
        viewModel.didScanSignedTransaction = { _ in deliveries += 1 }
        viewModel.viewDidLoad()
        let handler = try XCTUnwrap(output.didScanUR)
        let missingSignature = try UR(type: "crypto-hdkey", cbor: CBOR(Data([0xA0])))
        let signature = try UR(type: "ton-signature", cbor: CBOR(Data([0xA1, 0x02, 0x58, 0x40] + Array(repeating: 1, count: 64))))

        XCTAssertFalse(try handler(transaction))
        XCTAssertFalse(try handler(missingSignature))
        XCTAssertEqual(deliveries, 0)
        XCTAssertTrue(try handler(signature))
        XCTAssertEqual(deliveries, 1)
    }

    private func decodeMessage(_ encoder: UREncoder, with decoder: ScannerURDecoder) throws -> UR? {
        for _ in 0 ..< encoder.seqLen {
            do {
                return try decoder.decode(encoder.nextPart())
            } catch KeeperCore.URError.noResult {
                continue
            }
        }
        return nil
    }
}

private final class ScannerOutputProbe: ScannerViewModuleOutput {
    var didUpdateCameraState: ((ScannerCameraState) -> Void)?
    var didScanDeeplink: ((ScannedDeeplink) -> Void)?
    var didScanUR: ((UR) throws -> Bool)?
    var didFailScan: ((String?, Bool) -> Void)?
}

private struct NoURLOpener: URLOpener {
    func open(url _: URL) {}

    func canOpen(url _: URL) -> Bool {
        false
    }
}

private struct NoQRCodeGenerator: QrCodeMatrixGenerator {
    func generateMatrix(string _: String, configuration _: QrCodeGeneratorConfiguration) -> QrCodeMatrix? {
        nil
    }
}
