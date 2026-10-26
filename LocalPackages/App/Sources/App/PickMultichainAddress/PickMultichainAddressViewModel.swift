import Combine
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

@MainActor
protocol PickMultichainAddressModuleOutput: AnyObject {}

@MainActor
protocol PickMultichainAddressModuleInput: AnyObject {}

@MainActor
protocol PickMultichainAddressViewModel: ObservableObject {}

struct PickMultichainAddressItem: Identifiable {
    let address: MultichainWalletAddress
    let title: String
    let shortAddress: String
    let versionTag: String?
    let isNew: Bool
    let icon: UIImage

    var id: MultichainWalletAddress {
        address
    }
}

enum PickMultichainAddressPresentation {
    static let contentVerticalPadding: CGFloat = 8
}

@MainActor
final class PickMultichainAddressViewModelImplementation:
    PickMultichainAddressViewModel,
    PickMultichainAddressModuleOutput,
    PickMultichainAddressModuleInput
{
    @Published private(set) var items = [PickMultichainAddressItem]()

    var didSelectAddress: ((MultichainWalletAddress) -> Void)?
    var didCopyAddress: ((MultichainWalletAddress) -> Void)?
    var didRequestClose: (() -> Void)?

    init(
        addresses: [MultichainWalletAddress],
        newChainBadgeService: NewChainBadgeService
    ) {
        let chainCounts = Dictionary(grouping: addresses, by: \.chain)
            .mapValues { $0.count }
        items = addresses.map { address in
            let hasDuplicateChain = chainCounts[address.chain, default: 0] > 1
            return address.pickMultichainAddressItem(
                versionTag: hasDuplicateChain ? address.type?.rawValue : nil,
                isNew: newChainBadgeService.shouldShowBadge(for: address.chain)
            )
        }
    }

    func close() {
        didRequestClose?()
    }

    func selectAddress(_ address: MultichainWalletAddress) {
        didSelectAddress?(address)
    }

    func copyAddress(_ address: MultichainWalletAddress) {
        didCopyAddress?(address)
    }
}

private struct PickMultichainAddressConfiguration {
    let title: String
    let icon: UIImage
}

private extension MultichainWalletAddress {
    func pickMultichainAddressItem(versionTag: String?, isNew: Bool) -> PickMultichainAddressItem {
        PickMultichainAddressItem(
            address: self,
            title: chain.pickMultichainAddressConfiguration.title,
            shortAddress: address.shortReceiveAddress,
            versionTag: versionTag,
            isNew: isNew,
            icon: chain.pickMultichainAddressConfiguration.icon
        )
    }
}

private extension MultichainChain {
    var pickMultichainAddressConfiguration: PickMultichainAddressConfiguration {
        PickMultichainAddressConfiguration(
            title: shortDisplayTitle,
            icon: tokenIcon44
        )
    }
}
