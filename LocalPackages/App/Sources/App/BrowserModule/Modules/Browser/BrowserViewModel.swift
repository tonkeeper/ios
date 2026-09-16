import KeeperCore
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import UIKit

@MainActor
protocol BrowserModuleInput: AnyObject {
    var selectedBrowserTab: DappBrowserTab { get }

    func openExplore()
    func selectExploreNetworkFilter(_ chain: MultichainChain)
}

@MainActor
protocol BrowserModuleOutput: AnyObject {
    var didTapSearch: (() -> Void)? { get set }
    var didSelectCategory: ((PopularAppsCategory, MultichainChain?) -> Void)? { get set }
    var didSelectDapp: ((DappOpenIntent) -> Void)? { get set }
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
    func didTapExploreTab()
    func didTapConnectedTab()
}

@MainActor
final class BrowserViewModelImplementation: BrowserViewModel, BrowserModuleOutput {
    // MARK: - BrowserModuleOutput

    var didTapSearch: (() -> Void)?
    var didSelectCategory: ((PopularAppsCategory, MultichainChain?) -> Void)?
    var didSelectDapp: ((DappOpenIntent) -> Void)?
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
    private let analyticsController: DappBrowserAnalyticsController
    private var currentBrowserTab: DappBrowserTab = .explore

    // MARK: - Init

    init(
        exploreModuleInput: BrowserExploreModuleInput,
        exploreModuleOutput: BrowserExploreModuleOutput,
        connectedModuleOutput: BrowserConnectedModuleOutput,
        analyticsController: DappBrowserAnalyticsController
    ) {
        self.exploreModuleInput = exploreModuleInput
        self.exploreModuleOutput = exploreModuleOutput
        self.connectedModuleOutput = connectedModuleOutput
        self.analyticsController = analyticsController
    }
}

private extension BrowserViewModelImplementation {
    func configure() {
        exploreModuleOutput.didSelectCategory = { [weak self] category, chain in
            self?.didSelectCategory?(category, chain)
        }

        exploreModuleOutput.didSelectDapp = { [weak self] request in
            self?.didSelectDapp?(request)
        }

        exploreModuleOutput.didOpenDeeplink = { [weak self] deeplink in
            self?.didOpenDeeplink?(deeplink)
        }

        connectedModuleOutput.didSelectDapp = { [weak self] request in
            self?.didSelectDapp?(request)
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
                    self?.didTapExploreTab()
                }
            ),
            connectedButton: BrowserSegmentedControl.Model.Button(
                title: TKLocales.Browser.Tab.connected,
                tapAction: { [weak self] in
                    self?.didTapConnectedTab()
                }
            ),
            isExploreTabVisible: exploreTabVisible
        )

        didUpdateSegmentedControl?(segmentedControlModel)
        if exploreTabVisible {
            selectExplore()
        } else {
            selectConnected()
        }
    }
}

extension BrowserViewModelImplementation {
    func didTapExploreTab() {
        didTap(tab: .explore)
    }

    func didTapConnectedTab() {
        didTap(tab: .connected)
    }

    func selectExplore() {
        select(tab: .explore)
    }

    func selectConnected() {
        select(tab: .connected)
    }
}

private extension BrowserViewModelImplementation {
    func didTap(tab: DappBrowserTab) {
        guard currentBrowserTab != tab else { return }
        select(tab: tab)
        analyticsController.logBrowserTabClick(tab: tab)
    }

    func select(tab: DappBrowserTab) {
        currentBrowserTab = tab
        switch tab {
        case .explore:
            didSelectExplore?()
        case .connected:
            didSelectConnected?()
        }
    }
}

// MARK: -  BrowserModuleInput

extension BrowserViewModelImplementation: BrowserModuleInput {
    var selectedBrowserTab: DappBrowserTab {
        currentBrowserTab
    }

    func openExplore() {
        selectExplore()
    }

    func selectExploreNetworkFilter(_ chain: MultichainChain) {
        exploreModuleInput.selectNetworkFilter(chain)
    }
}
