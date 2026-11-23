import AppUI
import Foundation
import TKAppInfo
import TKLocalize

protocol OnboardingRootModuleOutput: AnyObject {
    var didTapCreateButton: (() -> Void)? { get set }
    var didTapImportButton: (() -> Void)? { get set }
    var didShowWelcome: (() -> Void)? { get set }
}

final class OnboardingRootViewModelImplementation: OnboardingRootModuleOutput {
    // MARK: - OnboardingRootModuleOutput

    var didTapCreateButton: (() -> Void)?
    var didTapImportButton: (() -> Void)?
    var didShowWelcome: (() -> Void)?

    let state: OnboardingRootScreenState

    init(termsURL: URL? = InfoProvider.termsOfServiceURL()) {
        state = OnboardingRootScreenState(
            title: TKLocales.Onboarding.title,
            caption: TKLocales.Onboarding.caption,
            createButtonTitle: TKLocales.Onboarding.Buttons.createNew,
            importButtonTitle: TKLocales.Onboarding.Buttons.importExisting,
            termsCaption: TKLocales.Onboarding.Terms.caption(TKLocales.Onboarding.Terms.title),
            termsLinkTitle: TKLocales.Onboarding.Terms.title,
            termsURL: termsURL
        )
    }

    func didTapCreate() {
        didTapCreateButton?()
    }

    func didTapImport() {
        didTapImportButton?()
    }

    func viewDidAppear() {
        didShowWelcome?()
    }
}
