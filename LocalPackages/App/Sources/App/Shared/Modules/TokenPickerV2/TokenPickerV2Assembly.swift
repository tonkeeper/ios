import Foundation
import KeeperCore
import TKCore

enum TokenPickerV2Presentation {
    case modal
    case pushed

    var configuresSheet: Bool {
        switch self {
        case .modal:
            return true
        case .pushed:
            return false
        }
    }

    var closesOnSelection: Bool {
        switch self {
        case .modal:
            return true
        case .pushed:
            return false
        }
    }
}

enum TokenPickerV2HeaderStyle {
    case modal
    case push
}

struct TokenPickerV2Assembly {
    private init() {}
    @MainActor
    static func module(
        title: String,
        wallet: Wallet,
        model: any TokenPickerV2Model,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        ignoresSafeArea: Bool = true,
        presentation: TokenPickerV2Presentation = .modal,
        headerStyle: TokenPickerV2HeaderStyle = .modal,
        waitsForSelectionCompletion: Bool = false,
        onBack: (() -> Void)? = nil
    ) -> MVVMModule<TokenPickerV2HostingViewController, TokenPickerV2ModuleOutput, Void> {
        let viewModel = TokenPickerV2ViewModelImplementation(
            headerTitle: title,
            tokenPickerModel: model,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            presentation: presentation,
            headerStyle: headerStyle,
            waitsForSelectionCompletion: waitsForSelectionCompletion,
            onBack: onBack
        )
        let viewController = TokenPickerV2HostingViewController(
            viewModel: viewModel,
            ignoresSafeArea: ignoresSafeArea,
            presentation: presentation
        )
        return .init(view: viewController, output: viewModel, input: ())
    }
}
