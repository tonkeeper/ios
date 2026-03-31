import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol ProviderPickerModuleOutput: AnyObject {
    var didTapClose: (() -> Void)? { get set }
    var didSelectMerchant: ((OnRampMerchantInfo) -> Void)? { get set }
}

protocol ProviderPickerViewModelProtocol: AnyObject {
    var didUpdateSnapshot: ((ProviderPickerViewController.Snapshot) -> Void)? { get set }

    func viewDidLoad()
    func didTapCloseButton()
    func didSelectMerchant(at index: Int)
}

struct ProviderPickerItem: Hashable {
    let merchant: OnRampMerchantInfo
    let isSelected: Bool
    let best: Bool
    let rateText: String?
    let amountLimitText: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(merchant.id)
    }

    static func == (lhs: ProviderPickerItem, rhs: ProviderPickerItem) -> Bool {
        lhs.merchant.id == rhs.merchant.id && lhs.isSelected == rhs.isSelected && lhs.best == rhs.best && lhs.rateText == rhs.rateText && lhs.amountLimitText == rhs.amountLimitText
    }
}

final class ProviderPickerViewModel: ProviderPickerModuleOutput, ProviderPickerViewModelProtocol {
    var didTapClose: (() -> Void)?
    var didSelectMerchant: ((OnRampMerchantInfo) -> Void)?

    var didUpdateSnapshot: ((ProviderPickerViewController.Snapshot) -> Void)?

    private let items: [ProviderPickerItem]

    init(items: [ProviderPickerItem]) {
        self.items = items
    }

    func viewDidLoad() {
        buildSnapshot()
    }

    func didTapCloseButton() {
        didTapClose?()
    }

    func didSelectMerchant(at index: Int) {
        guard index >= 0, index < items.count else { return }
        didSelectMerchant?(items[index].merchant)
    }

    private func buildSnapshot() {
        var snapshot = ProviderPickerViewController.Snapshot()
        snapshot.appendSections([.providers])
        snapshot.appendItems(items, toSection: .providers)
        didUpdateSnapshot?(snapshot)
    }
}
