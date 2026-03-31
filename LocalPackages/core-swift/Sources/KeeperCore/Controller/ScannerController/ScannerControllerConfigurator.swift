import Foundation
import TonSwift
import URKit

public protocol ScannerControllerConfigurator {
    func handleQRCode(_ qrCode: String) throws -> Deeplink
    func handleQRCodeUR(_ qrCode: String) throws -> UR
}

public enum URError: Error {
    case noResult

    public var errorDescription: String? {
        switch self {
        case .noResult:
            return "URError: no result"
        }
    }
}

public struct DefaultScannerControllerConfigurator: ScannerControllerConfigurator {
    private let deeplinkParser = DeeplinkParser()
    private let urDecoder = URDecoder()
    private let extensions: [QRScannerExtension]

    public init(extensions: [QRScannerExtension]) {
        self.extensions = extensions
    }

    public func handleQRCode(_ qrCode: String) throws -> Deeplink {
        do {
            _ = try TronRecipient(address: qrCode)
            return createTransferDeeplink(for: qrCode)
        } catch {}

        do {
            _ = try Address.parse(qrCode)
            return createTransferDeeplink(for: qrCode)
        } catch {}

        if let extensionsDeeplink = processWithExtensions(qrCode) {
            return extensionsDeeplink
        }

        return try deeplinkParser.parse(string: qrCode)
    }

    public func handleQRCodeUR(_ qrCode: String) throws -> UR {
        urDecoder.receivePart(qrCode)

        guard let result = urDecoder.result else {
            throw URError.noResult
        }
        return try result.get()
    }

    private func createTransferDeeplink(for recipient: String) -> Deeplink {
        Deeplink.transfer(
            .sendTransfer(
                Deeplink.TransferData(
                    recipient: recipient,
                    amount: nil,
                    comment: nil,
                    jettonAddress: nil,
                    expirationTimestamp: nil,
                    successReturn: nil
                )
            )
        )
    }

    private func processWithExtensions(_ qrCode: String) -> Deeplink? {
        guard
            let matchedExtension = extensions.first(
                where: { qrCode.matches($0.regexp) && QRScannerExtension.processors[$0.version] != nil }
            )
        else { return nil }

        return QRScannerExtension.processors[matchedExtension.version]?.process(matchedExtension, qrCode: qrCode)
    }
}

private extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}

public struct QRScannerExtension: Codable, Hashable {
    /// [Protocol version: Processor]
    fileprivate static let processors: [Int: Processor.Type] = [1: V1Processor.self]

    let version: Int
    let regexp: String
    let url: String
}

private extension QRScannerExtension {
    protocol Processor {
        static func process(_ extension: QRScannerExtension, qrCode: String) -> Deeplink?
    }
}

private extension QRScannerExtension {
    struct V1Processor: Processor {
        static func process(_ processingExtension: QRScannerExtension, qrCode: String) -> Deeplink? {
            let dappURLString = processingExtension.url.replacingOccurrences(of: "{{QR_CODE}}", with: qrCode)
            return URL(string: dappURLString).flatMap(Deeplink.dapp)
        }
    }
}
