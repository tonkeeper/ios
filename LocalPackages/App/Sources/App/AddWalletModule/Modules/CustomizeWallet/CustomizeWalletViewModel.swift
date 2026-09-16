import Foundation
import KeeperCore
import TKCore
import TKLocalize

public struct CustomizeWalletModel {
    public let name: String
    public let tintColor: WalletTintColor
    public let icon: WalletIcon
}

protocol CustomizeWalletModuleOutput: AnyObject {
    var didCustomizeWallet: ((CustomizeWalletModel) -> Void)? { get set }
}

final class CustomizeWalletViewModel: ObservableObject, CustomizeWalletModuleOutput {
    // MARK: - CustomizeWalletModuleOutput

    var didCustomizeWallet: ((CustomizeWalletModel) -> Void)?

    // MARK: - State

    struct HeaderButton {
        enum Icon {
            case back
            case close
            case chevronDown
        }

        let icon: Icon
        let action: () -> Void
    }

    @Published var leftHeaderButton: HeaderButton?
    @Published var rightHeaderButton: HeaderButton?
    @Published var nameInput: String
    @Published private(set) var tintColor: WalletTintColor
    @Published private(set) var icon: WalletIcon
    @Published private(set) var icons: [WalletIcon] = []
    @Published private(set) var isContinueEnabled = true
    @Published private(set) var isContinueLoading = false

    let title = TKLocales.CustomizeWallet.title
    let description = TKLocales.CustomizeWallet.description
    let namePlaceholder = TKLocales.CustomizeWallet.inputPlaceholder

    var continueButtonTitle: String? {
        switch configurator.continueButtonMode {
        case .hidden:
            nil
        case let .visible(title, _):
            title
        }
    }

    @MainActor
    func start() async {
        guard icons.isEmpty else { return }
        let items = await createIconPickerItems()
        guard !items.isEmpty else { return }
        icons = items
        if !items.contains(icon), let first = items.first {
            icon = first
        }
    }

    func setName(_ input: String) {
        let isNameValid = !input.isEmpty
        name = isNameValid ? input : defaultName
        isContinueEnabled = isNameValid
        configurator.didEditName()
    }

    func select(color: WalletTintColor) {
        tintColor = color
        configurator.didSelectColor()
    }

    func select(icon: WalletIcon) {
        self.icon = icon
        configurator.didSelectColor()
    }

    func didTapContinue() {
        guard case let .visible(_, action) = configurator.continueButtonMode else { return }
        isContinueEnabled = false
        isContinueLoading = true
        action()
    }

    // MARK: - Data Source

    private var emojiDataSource = EmojisDataSource()

    // MARK: - Dependencies

    private var name: String
    private let defaultName: String
    private let configurator: CustomizeWalletViewModelConfigurator

    init(
        name: String? = nil,
        tintColor: WalletTintColor? = nil,
        icon: WalletIcon? = nil,
        configurator: CustomizeWalletViewModelConfigurator
    ) {
        let resolvedName = name ?? .defaultWalletName
        self.name = resolvedName
        defaultName = resolvedName
        nameInput = resolvedName
        self.tintColor = tintColor ?? .defaultColor
        self.icon = icon ?? .default
        self.configurator = configurator

        configurator.didCustomizeWallet = { [weak self] in
            self?.didFinishCustomization()
        }
    }
}

private extension CustomizeWalletViewModel {
    func createIconPickerItems() async -> [WalletIcon] {
        var emojis = await emojiDataSource.loadData()

        if #unavailable(iOS 16.4) {
            emojis = emojis.filter { $0.emojiVersion.major <= 1 }
        }

        let images = WalletIcon.Image.allCases

        let imageItems = images.map { image in
            WalletIcon.icon(image)
        }
        let emojiItems = emojis.map { emoji in
            WalletIcon.emoji(emoji.emoji)
        }
        return imageItems + emojiItems
    }

    func didFinishCustomization() {
        let model = CustomizeWalletModel(
            name: name,
            tintColor: tintColor,
            icon: icon
        )
        didCustomizeWallet?(model)
    }
}

private extension WalletIcon {
    static var `default`: WalletIcon {
        .icon(.wallet)
    }
}

private extension String {
    static let defaultWalletName = TKLocales.CustomizeWallet.defaultWalletName
}
