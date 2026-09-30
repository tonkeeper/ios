import Combine
import KeeperCore
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class BrowserMultichainViewModelImplementation: ObservableObject, BrowserModuleOutput {
    enum SelectedTab {
        case explore
        case connected
    }

    // MARK: - BrowserModuleOutput

    var didTapSearch: (() -> Void)?
    var didSelectCategory: ((PopularAppsCategory, MultichainChain?) -> Void)?
    var didSelectDapp: ((DappOpenIntent) -> Void)?
    var didOpenDeeplink: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)?

    // MARK: - State

    @Published private(set) var isExploreTabVisible: Bool
    @Published private(set) var selectedTab: SelectedTab
    @Published var scrollToTopRequest = UUID()

    private var didStart = false
    private var shouldSelectExploreWhenVisible: Bool

    // MARK: - Dependencies

    private let exploreModuleInput: BrowserExploreModuleInput
    private let exploreModuleOutput: BrowserExploreModuleOutput
    private let connectedModuleOutput: BrowserConnectedModuleOutput
    private let analyticsController: DappBrowserAnalyticsController

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
        let isExploreTabVisible = exploreModuleInput.isExploreTabVisible
        self.isExploreTabVisible = isExploreTabVisible
        self.selectedTab = isExploreTabVisible ? .explore : .connected
        self.shouldSelectExploreWhenVisible = !isExploreTabVisible && exploreModuleInput.canShowExploreTab
    }

    func viewDidLoad() {
        guard !didStart else { return }
        didStart = true
        configure()
    }

    func didTapExploreTab() {
        didTap(tab: .explore)
    }

    func didTapConnectedTab() {
        didTap(tab: .connected)
    }

    func selectExplore() {
        select(tab: .explore)
    }

    func didTapSearchBar() {
        didTapSearch?()
    }

    func requestScrollToTop() {
        scrollToTopRequest = UUID()
    }
}

private extension BrowserMultichainViewModelImplementation {
    func didTap(tab: SelectedTab) {
        guard select(tab: tab) else {
            return
        }
        analyticsController.logBrowserTabClick(tab: tab.browserTab)
    }

    @discardableResult
    func select(tab: SelectedTab) -> Bool {
        guard selectedTab != tab else {
            return false
        }

        let previousTab = selectedTab

        switch tab {
        case .explore:
            guard isExploreTabVisible else {
                shouldSelectExploreWhenVisible = exploreModuleInput.canShowExploreTab
                selectedTab = .connected
                return false
            }
            shouldSelectExploreWhenVisible = false
            selectedTab = .explore
        case .connected:
            shouldSelectExploreWhenVisible = false
            selectedTab = .connected
        }

        return previousTab != selectedTab
    }

    func configure() {
        exploreModuleOutput.didSelectCategory = { [weak self] category, chain in
            self?.didSelectCategory?(category, chain)
        }

        exploreModuleOutput.didSelectDapp = { [weak self] request in
            self?.didSelectDapp?(request)
        }

        exploreModuleOutput.didOpenDeeplink = { [weak self] deeplink, utm in
            self?.didOpenDeeplink?(deeplink, utm)
        }

        connectedModuleOutput.didSelectDapp = { [weak self] request in
            self?.didSelectDapp?(request)
        }

        exploreModuleOutput.didUpdateExploreTabVisible = { [weak self] isVisible in
            self?.updateExploreTabVisibility(isVisible)
        }
    }

    func updateExploreTabVisibility(_ isVisible: Bool) {
        let wasVisible = isExploreTabVisible
        isExploreTabVisible = isVisible
        if isVisible {
            if !wasVisible, shouldSelectExploreWhenVisible {
                selectExplore()
            }
            return
        } else if !exploreModuleInput.canShowExploreTab {
            shouldSelectExploreWhenVisible = false
            selectedTab = .connected
        } else if selectedTab == .explore {
            shouldSelectExploreWhenVisible = true
            selectedTab = .connected
        }
    }
}

private extension BrowserMultichainViewModelImplementation.SelectedTab {
    var browserTab: DappBrowserTab {
        switch self {
        case .explore:
            return .explore
        case .connected:
            return .connected
        }
    }
}

// MARK: - BrowserModuleInput

extension BrowserMultichainViewModelImplementation: BrowserModuleInput {
    var selectedBrowserTab: DappBrowserTab {
        if shouldSelectExploreWhenVisible {
            return .explore
        }
        return selectedTab.browserTab
    }

    func openExplore() {
        selectExplore()
    }

    func selectExploreNetworkFilter(_ chain: MultichainChain) {
        exploreModuleInput.selectNetworkFilter(chain)
    }
}
