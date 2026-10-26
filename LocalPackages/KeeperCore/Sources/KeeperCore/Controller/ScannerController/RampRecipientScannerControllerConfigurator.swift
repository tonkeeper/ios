import Foundation
import TKLocalize
import URKit

public struct RampRecipientScannerControllerConfigurator: ScannerControllerConfigurator {
    @frozen public enum Error: Swift.Error, Equatable, LocalizedError {
        case invalidAddress(networkName: String)

        public var errorDescription: String? {
            switch self {
            case let .invalidAddress(networkName):
                TKLocales.Send.invalidAddressForNetwork(networkName)
            }
        }
    }

    private let addressFormat: RampAddressFormat?
    private let networkName: String

    public init(assetId: String, networkName: String) {
        addressFormat = RampAddressFormat(assetId: assetId)
        self.networkName = networkName
    }

    public func handleQRCode(_ qrCode: String) throws -> Deeplink {
        guard let addressFormat else {
            return transferDeeplink(recipient: qrCode.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let recipient = addressFormat.recipient(fromQRCode: qrCode) else {
            throw Error.invalidAddress(networkName: networkName)
        }
        return transferDeeplink(recipient: recipient)
    }

    public func handleQRCodeUR(_ qrCode: String) throws -> UR {
        throw URError.noResult
    }
}

private extension RampRecipientScannerControllerConfigurator {
    func transferDeeplink(recipient: String) -> Deeplink {
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
