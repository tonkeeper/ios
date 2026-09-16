import Combine
import KeeperCore
import TKLocalize
import TKUIKit

@MainActor
protocol AddWalletOptionPickerModuleOutput: AnyObject {
    var didSelectOption: ((AddWalletOption) -> Void)? { get set }
    var didRequestClose: (() -> Void)? { get set }
}

@MainActor
protocol AddWalletOptionPickerViewModel: ObservableObject {}

@MainActor
final class AddWalletOptionPickerViewModelImplementation: AddWalletOptionPickerViewModel, AddWalletOptionPickerModuleOutput {
    var didSelectOption: ((AddWalletOption) -> Void)?
    var didRequestClose: (() -> Void)?
    @Published private(set) var sections = [AddWalletOptionPickerSection]()

    func viewDidLoad() {
        sections = createOptionsSections()
    }

    func close() {
        didRequestClose?()
    }

    func selectItem(_ item: AddWalletOptionPickerItem) {
        didSelectOption?(item.option)
    }

    private let options: [AddWalletOption]
    private let multichainImportChains: [MultichainChain]

    init(options: [AddWalletOption], multichainImportChains: [MultichainChain]) {
        self.options = options
        self.multichainImportChains = multichainImportChains
    }

    private func createOptionsSections() -> [AddWalletOptionPickerSection] {
        AddWalletOptionPickerSectionType.allCases.compactMap { type in
            let items = type.options
                .filter(options.contains)
                .map(config(for:))

            guard !items.isEmpty else {
                return nil
            }

            return AddWalletOptionPickerSection(
                type: type,
                header: type.header,
                items: items
            )
        }
    }

    private func config(for option: AddWalletOption) -> AddWalletOptionPickerItem {
        let showsImportChains = option == .importRegular && !multichainImportChains.isEmpty
        return AddWalletOptionPickerItem(
            option: option,
            title: option.title,
            subtitle: showsImportChains
                ? TKLocales.AddWallet.Items.ExistingWallet.subtitleMultichain
                : option.subtitle,
            icon: option.icon,
            tag: option.badgeTagSwiftUIConfiguration,
            chains: showsImportChains ? multichainImportChains : []
        )
    }
}
