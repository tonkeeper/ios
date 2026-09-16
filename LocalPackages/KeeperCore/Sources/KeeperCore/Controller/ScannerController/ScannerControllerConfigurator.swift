import Foundation
import TonSwift
import URKit

public protocol ScannerControllerConfigurator {
    func handleQRCode(_ qrCode: String) throws -> Deeplink
    func handleQRCodeUR(_ qrCode: String) throws -> UR
}

public enum URError: Error {
    case noResult
}

public struct DefaultScannerControllerConfigurator: ScannerControllerConfigurator {
    private let deeplinkParser: DeeplinkParser
    private let urDecoder = URDecoder()
    private let extensions: [QRScannerExtension]
    private let isMultichainEnabled: Bool

    public init(
        extensions: [QRScannerExtension],
        deeplinkParser: DeeplinkParser,
        isMultichainEnabled: Bool
    ) {
        self.extensions = extensions
        self.deeplinkParser = deeplinkParser
        self.isMultichainEnabled = isMultichainEnabled
    }

    public func handleQRCode(_ qrCode: String) throws -> Deeplink {
        let trimmedQRCode = qrCode.trimmingCharacters(in: .whitespacesAndNewlines)

        if let transferDeeplink = transferDeeplink(for: trimmedQRCode) {
            return transferDeeplink
        }

        if let extensionsDeeplink = processWithExtensions(qrCode) {
            return extensionsDeeplink
        }

        return try deeplinkParser.parse(string: qrCode, source: .qr)
    }

    public func handleQRCodeUR(_ qrCode: String) throws -> UR {
        urDecoder.receivePart(qrCode)

        guard let result = urDecoder.result else {
            throw URError.noResult
        }
        return try result.get()
    }

    private func transferDeeplink(for recipient: String) -> Deeplink? {
        isMultichainEnabled
            ? multichainTransferDeeplink(for: recipient)
            : legacyTransferDeeplink(for: recipient)
    }

    private func legacyTransferDeeplink(for recipient: String) -> Deeplink? {
        guard isTronRecipient(recipient) || isTonRecipient(recipient) else {
            return nil
        }
        return .transfer(
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

    private func multichainTransferDeeplink(for recipient: String) -> Deeplink? {
        guard let candidates = MultichainRecipientCandidates(string: recipient) else {
            return nil
        }
        return .transfer(.multichainSendTransfer(candidates))
    }

    private func processWithExtensions(_ qrCode: String) -> Deeplink? {
        guard
            let matchedExtension = extensions.first(
                where: { qrCode.matches($0.regexp) && QRScannerExtension.processors[$0.version] != nil }
            )
        else { return nil }

        return QRScannerExtension.processors[matchedExtension.version]?.process(matchedExtension, qrCode: qrCode)
    }

    private func isTronRecipient(_ recipient: String) -> Bool {
        (try? TronRecipient(address: recipient)) != nil
    }

    private func isTonRecipient(_ recipient: String) -> Bool {
        (try? TonSwift.Address.parse(recipient)) != nil
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
