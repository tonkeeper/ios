import KeeperCore
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import UIKit

@MainActor
protocol BrowserModuleInput: AnyObject {
    func openExplore()
}

@MainActor
protocol BrowserModuleOutput: AnyObject {
    var didTapSearch: (() -> Void)? { get set }
    var didSelectCategory: ((PopularAppsCategory) -> Void)? { get set }
    var didSelectDapp: ((Dapp) -> Void)? { get set }
    var didOpenDeeplink: ((Deeplink) -> Void)? { get set }
}

@MainActor
protocol BrowserViewModel: AnyObject {
    var didUpdateSegmentedControl: ((BrowserSegmentedControl.Model) -> Void)? { get set }
    var didSelectExplore: (() -> Void)? { get set }
    var didSelectConnected: (() -> Void)? { get set }
    var didUpdateRightHeaderButton: ((BrowserHeaderRightButtonModel) -> Void)? { get set }

    func viewDidLoad()
    func viewWillAppear()
    func didTapSearchBar()
}

@MainActor
final class BrowserViewModelImplementation: BrowserViewModel, BrowserModuleOutput {
    // MARK: - BrowserModuleOutput

    var didTapSearch: (() -> Void)?
    var didSelectCategory: ((PopularAppsCategory) -> Void)?
    var didSelectDapp: ((Dapp) -> Void)?
    var didOpenDeeplink: ((Deeplink) -> Void)?

    // MARK: - BrowserViewModel

    var didUpdateSegmentedControl: ((BrowserSegmentedControl.Model) -> Void)?
    var didSelectExplore: (() -> Void)?
    var didSelectConnected: (() -> Void)?
    var didUpdateRightHeaderButton: ((BrowserHeaderRightButtonModel) -> Void)?

    func viewDidLoad() {
        configure()
        updateSegmentedControl(exploreTabVisible: exploreModuleInput.isExploreTabVisible)
    }

    func viewWillAppear() {}

    func didTapSearchBar() {
        didTapSearch?()
    }

    // MARK: - Dependencies

    private let exploreModuleInput: BrowserExploreModuleInput
    private let exploreModuleOutput: BrowserExploreModuleOutput
    private let connectedModuleOutput: BrowserConnectedModuleOutput
    private let analyticsProvider: AnalyticsProvider

    // MARK: - Init

    init(
        exploreModuleInput: BrowserExploreModuleInput,
        exploreModuleOutput: BrowserExploreModuleOutput,
        connectedModuleOutput: BrowserConnectedModuleOutput,
        analyticsProvider: AnalyticsProvider
    ) {
        self.exploreModuleInput = exploreModuleInput
        self.exploreModuleOutput = exploreModuleOutput
        self.connectedModuleOutput = connectedModuleOutput
        self.analyticsProvider = analyticsProvider
    }
}

private extension BrowserViewModelImplementation {
    func configure() {
        exploreModuleOutput.didSelectCategory = { [weak self] category in
            self?.didSelectCategory?(category)
        }

        exploreModuleOutput.didSelectDapp = { [weak self] dapp in
            self?.didSelectDapp?(dapp)
        }

        exploreModuleOutput.didOpenDeeplink = { [weak self] deeplink in
            self?.didOpenDeeplink?(deeplink)
        }

        connectedModuleOutput.didSelectDapp = { [weak self] dapp in
            self?.didSelectDapp?(dapp)
        }

        exploreModuleOutput.didUpdateExploreTabVisible = { [weak self] isVisible in
            self?.updateSegmentedControl(exploreTabVisible: isVisible)
        }
    }

    private func updateSegmentedControl(exploreTabVisible: Bool) {
        let segmentedControlModel = BrowserSegmentedControl.Model(
            exploreButton: BrowserSegmentedControl.Model.Button(
                title: TKLocales.Browser.Tab.explore,
                tapAction: { [weak self] in
                    self?.didSelectExplore?()
                }
            ),
            connectedButton: BrowserSegmentedControl.Model.Button(
                title: TKLocales.Browser.Tab.connected,
                tapAction: { [weak self] in
                    self?.didSelectConnected?()
                }
            ),
            isExploreTabVisible: exploreTabVisible
        )

        didUpdateSegmentedControl?(segmentedControlModel)
        if exploreTabVisible {
            didSelectExplore?()
        } else {
            didSelectConnected?()
        }
    }
}

// MARK: -  BrowserModuleInput

extension BrowserViewModelImplementation: BrowserModuleInput {
    func openExplore() {
        didSelectExplore?()
    }
}
