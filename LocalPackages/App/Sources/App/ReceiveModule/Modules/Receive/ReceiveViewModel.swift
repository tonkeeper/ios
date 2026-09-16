import Combine
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol ReceiveModuleOutput: AnyObject {
    var didRequestClose: (() -> Void)? { get set }
}

protocol ReceiveModuleInput: AnyObject {}

struct ReceiveNetworkViewData: Identifiable {
    let chain: MultichainChain
    let addressTitle: String
    let title: String
    let address: String
    let shortAddress: String
    let disclaimer: String
    let avatarImageSource: AssetAvatarViewImageSource
    let primaryColor: UIColor
    let secondaryColor: UIColor

    var id: MultichainChain {
        chain
    }
}

final class ReceiveViewModelImplementation: ObservableObject, ReceiveModuleOutput, ReceiveModuleInput {
    @Published private(set) var qrCodeMatrix: QrCodeMatrix?
    let selectedNetwork: ReceiveNetworkViewData

    var didRequestClose: (() -> Void)?
    var didRequestShare: ((String) -> Void)?
    var didRequestCopy: ((String) -> Void)?

    private let address: ReceiveAddressPreview
    private let qrCodeGenerationController: QrCodeMatrixGenerationController

    init(
        address: ReceiveAddressPreview,
        qrCodeGenerator: QrCodeMatrixGenerator
    ) {
        self.address = address
        self.qrCodeGenerationController = QrCodeMatrixGenerationController(
            qrCodeGenerator: qrCodeGenerator,
            centerCutoutSize: Constants.qrCodeCenterCutoutSize
        )
        let network = address.receiveNetworkViewData
        selectedNetwork = network
    }

    func viewDidLoad() {
        regenerateQRCode()
    }

    func close() {
        didRequestClose?()
    }

    func copyAddress() {
        didRequestCopy?(address.address)
    }

    func shareSelectedAddress() {
        didRequestShare?(address.address)
    }
}

extension ReceiveViewModelImplementation {
    func regenerateQRCode() {
        qrCodeGenerationController.generate(
            payload: address.qrPayload
        ) { [weak self] matrix in
            guard let self, qrCodeMatrix != matrix else {
                return
            }
            qrCodeMatrix = matrix
        }
    }
}

private extension ReceiveViewModelImplementation {
    enum Constants {
        static let qrCodeCenterCutoutSize = CGSize(width: 72, height: 72)
    }
}

private struct ReceiveMultichainConfiguration {
    let title: String
    let disclaimer: String
    let icon: UIImage
    let badgeIcon: UIImage
    let primaryColor: UIColor
    let secondaryColor: UIColor
}

private extension ReceiveAddressPreview {
    var receiveNetworkViewData: ReceiveNetworkViewData {
        let configuration = chain.receiveMultichainConfiguration
        return ReceiveNetworkViewData(
            chain: chain,
            addressTitle: TKLocales.Receive.Multichain.addressTitle(configuration.title),
            title: configuration.title,
            address: address,
            shortAddress: address.shortReceiveAddress,
            disclaimer: configuration.disclaimer,
            avatarImageSource: avatarImageSource(configuration: configuration),
            primaryColor: configuration.primaryColor,
            secondaryColor: configuration.secondaryColor
        )
    }

    func avatarImageSource(configuration: ReceiveMultichainConfiguration) -> AssetAvatarViewImageSource {
        guard let asset else {
            return .image(configuration.icon)
        }

        switch asset.icon {
        case let .image(image):
            return .image(image, chainIcon: configuration.badgeIcon)
        case let .url(url):
            return .url(url, chainIcon: configuration.badgeIcon)
        }
    }
}

private extension MultichainChain {
    var receiveMultichainConfiguration: ReceiveMultichainConfiguration {
        ReceiveMultichainConfiguration(
            title: shortDisplayTitle,
            disclaimer: TKLocales.Receive.Multichain.disclaimer(
                disclaimerAssetName,
                disclaimerAssetTicker,
                disclaimerNetworkTitle
            ),
            icon: tokenIcon44,
            badgeIcon: tokenIcon20,
            primaryColor: primaryColor,
            secondaryColor: primaryColor.withAlphaComponent(0.16)
        )
    }

    var disclaimerAssetName: String {
        switch self {
        case .ton:
            TKLocales.Receive.Multichain.Networks.Ton.disclaimerTitle
        case .eth, .btc, .base, .bsc, .arb, .tron:
            disclaimerNetworkTitle
        }
    }

    var disclaimerAssetTicker: String {
        self == .ton ? TonInfo.symbol : tokenType
    }

    var disclaimerNetworkTitle: String {
        switch self {
        case .bsc:
            TKLocales.Receive.Multichain.Networks.Smartchain.disclaimerTitle
        case .ton, .eth, .btc, .base, .arb, .tron:
            shortDisplayTitle
        }
    }

    var primaryColor: UIColor {
        switch self {
        case .ton, .eth, .base, .arb:
            .Accent.blue
        case .btc, .bsc:
            .Accent.orange
        case .tron:
            .Accent.red
        }
    }
}

extension String {
    var shortReceiveAddress: String {
        guard count > 14 else { return self }
        return "\(prefix(4))...\(suffix(4))"
    }
}
