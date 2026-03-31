import Foundation
import TKLocalize
import TKUIKit
import UIKit

protocol AddWalletOptionPickerModuleOutput: AnyObject {
    var didSelectOption: ((AddWalletOption) -> Void)? { get set }
}

protocol AddWalletOptionPickerViewModel: AnyObject {
    var didUpdateHeaderViewModel: ((TKTitleDescriptionView.Model) -> Void)? { get set }
    var didUpdateOptionsSections: (([AddWalletOptionPickerSection]) -> Void)? { get set }

    func viewDidLoad()
    func didSelectItem(_ item: AddWalletOptionPickerItem)
}

final class AddWalletOptionPickerViewModelImplementation: AddWalletOptionPickerViewModel, AddWalletOptionPickerModuleOutput {
    // MARK: - AddWalletOptionPickerModuleOutput

    var didSelectOption: ((AddWalletOption) -> Void)?

    // MARK: - AddWalletOptionPickerViewModel

    var didUpdateHeaderViewModel: ((TKTitleDescriptionView.Model) -> Void)?
    var didUpdateOptionsSections: (([AddWalletOptionPickerSection]) -> Void)?

    func viewDidLoad() {
        didUpdateHeaderViewModel?(createHeaderViewModel())
        didUpdateOptionsSections?(createOptionsSections())
    }

    func didSelectItem(_ item: AddWalletOptionPickerItem) {
        didSelectOption?(item.option)
    }

    private let options: [AddWalletOption]

    init(options: [AddWalletOption]) {
        self.options = options
    }

    private func createHeaderViewModel() -> TKTitleDescriptionView.Model {
        TKTitleDescriptionView.Model(
            title: TKLocales.AddWallet.title,
            bottomDescription: TKLocales.AddWallet.description
        )
    }

    private func createOptionsSections() -> [AddWalletOptionPickerSection] {
        let grouped = Dictionary(grouping: options) { SectionType(option: $0) }

        var result: [AddWalletOptionPickerSection] = []

        let sectionOrder: [SectionType] = [.main, .other, .developer]

        for sectionType in sectionOrder {
            guard let options = grouped[sectionType] else { continue }

            for (index, option) in options.enumerated() {
                let header = (index == 0) ? sectionType.header : nil
                let section = AddWalletOptionPickerSection(
                    header: header,
                    items: [
                        AddWalletOptionPickerItem(option: option, cellConfiguration: config(for: option)),
                    ]
                )
                result.append(section)
            }
        }
        return result
    }

    private func config(for option: AddWalletOption) -> TKListItemCell.Configuration {
        TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                iconViewConfiguration: TKListItemIconView.Configuration(
                    content: .image(
                        TKImageView.Model(
                            image: .image(option.icon),
                            tintColor: .Accent.blue
                        )
                    ),
                    alignment: .center,
                    size: CGSize(width: 28, height: 28)
                ),
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(
                        title: option.title
                    ),
                    captionViewsConfigurations: [TKListItemTextView.Configuration(
                        text: option.subtitle,
                        color: .Text.secondary,
                        textStyle: .body2,
                        numberOfLines: 0
                    )]
                )
            )
        )
    }
}

private enum SectionType {
    case main
    case other
    case developer

    var header: String? {
        switch self {
        case .main: return nil
        case .other: return TKLocales.AddWallet.Sections.otherOptions
        case .developer: return TKLocales.AddWallet.Sections.forDevelopers
        }
    }

    init(option: AddWalletOption) {
        switch option {
        case .createRegular, .importRegular, .signer, .keystone, .ledger:
            self = .main
        case .importWatchOnly:
            self = .other
        case .importTestnet:
            self = .developer
        case .importTetra:
            self = .developer
        }
    }
}
