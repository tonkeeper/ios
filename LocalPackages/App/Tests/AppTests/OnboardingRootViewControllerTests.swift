@testable import App
import TKLocalize
import XCTest

@MainActor
final class OnboardingRootViewControllerTests: XCTestCase {
    func testViewDidAppearNotifiesWelcomeOutputEachTime() {
        let viewModel = OnboardingRootViewModelImplementation()
        let viewController = OnboardingRootViewController(viewModel: viewModel)
        var appearances = 0

        viewModel.didShowWelcome = {
            appearances += 1
        }

        viewController.viewDidAppear(false)
        viewController.viewDidAppear(false)

        XCTAssertEqual(appearances, 2)
    }

    func testButtonTapsReachTheModuleOutput() {
        let viewModel = OnboardingRootViewModelImplementation()
        var created = 0
        var imported = 0

        viewModel.didTapCreateButton = { created += 1 }
        viewModel.didTapImportButton = { imported += 1 }

        viewModel.didTapCreate()
        viewModel.didTapImport()

        XCTAssertEqual(created, 1)
        XCTAssertEqual(imported, 1)
    }

    func testStateCarriesTheScreensOwnTitleAndATappableTermsLink() {
        let state = OnboardingRootViewModelImplementation().state

        XCTAssertEqual(state.title, TKLocales.Onboarding.title)
        XCTAssertEqual(state.termsLinkTitle, TKLocales.Onboarding.Terms.title)
        XCTAssertTrue(state.termsCaption.contains(state.termsLinkTitle))
        XCTAssertNotNil(state.termsURL)
    }
}
