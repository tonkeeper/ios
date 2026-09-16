import Foundation
import TKUIKit
import UIKit

final class SettingsListToastTestingConfigurator: SettingsListConfigurator {
    var didUpdateState: ((SettingsListState) -> Void)?

    var title: String {
        "Toast Testing"
    }

    func getInitialState() -> SettingsListState {
        SettingsListState(
            sections: [
                createPresetsSection(),
                createPlacementSection(),
                createDismissRuleSection(),
                createInteractionsSection(),
                createShapeSection(),
            ]
        )
    }

    // MARK: - Presets

    private func createPresetsSection() -> SettingsListSection {
        .items(
            SettingsListItemsSection(
                items: [
                    .listItem(createActionItem(title: "Default", id: "toast_default") {
                        ToastPresenter.showToast(
                            configuration: .defaultConfiguration(text: "Default toast")
                        )
                    }),
                    .listItem(createActionItem(title: "Copied", id: "toast_copied") {
                        ToastPresenter.showToast(configuration: .copied)
                    }),
                    .listItem(createActionItem(title: "Loading", id: "toast_loading") {
                        ToastPresenter.showToast(configuration: .loading)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            ToastPresenter.hideToast()
                        }
                    }),
                    .listItem(createActionItem(title: "Failed", id: "toast_failed") {
                        ToastPresenter.showToast(configuration: .failed)
                    }),
                    .listItem(createActionItem(title: "Confirmed", id: "toast_confirmed") {
                        ToastPresenter.showToast(
                            configuration: .confirmed(text: "Transaction confirmed")
                        )
                    }),
                    .listItem(createActionItem(title: "Warning", id: "toast_warning") {
                        ToastPresenter.showToast(
                            configuration: .warning(text: "No internet connection")
                        )
                    }),
                ],
                header: SettingsListSectionHeader(title: "Presets")
            )
        )
    }

    // MARK: - Placement

    private func createPlacementSection() -> SettingsListSection {
        .items(
            SettingsListItemsSection(
                items: [
                    .listItem(createActionItem(title: "Default placement", id: "toast_placement_default") {
                        ToastPresenter.showToast(
                            configuration: .warning(text: "Default placement")
                                .withPlacement(.default)
                        )
                    }),
                    .listItem(createActionItem(title: "Navigation bar placement", id: "toast_placement_navbar") {
                        ToastPresenter.showToast(
                            configuration: .warning(text: "Navigation bar placement")
                                .withPlacement(.navigationBar)
                        )
                    }),
                ],
                header: SettingsListSectionHeader(title: "Placement")
            )
        )
    }

    // MARK: - Dismiss Rule

    private func createDismissRuleSection() -> SettingsListSection {
        .items(
            SettingsListItemsSection(
                items: [
                    .listItem(createActionItem(title: "Auto dismiss (default)", id: "toast_dismiss_default") {
                        ToastPresenter.showToast(
                            configuration: .defaultConfiguration(text: "Auto dismiss (2s)")
                        )
                    }),
                    .listItem(createActionItem(title: "Custom duration (5s)", id: "toast_dismiss_5s") {
                        ToastPresenter.showToast(
                            configuration: .init(
                                title: "Dismisses in 5 seconds",
                                dismissRule: .duration(5)
                            )
                        )
                    }),
                    .listItem(createActionItem(title: "No auto dismiss", id: "toast_dismiss_none") {
                        ToastPresenter.showToast(
                            configuration: .init(
                                title: "Tap to dismiss manually",
                                shape: .oval,
                                dismissRule: .none,
                                onTap: {
                                    ToastPresenter.hideToast()
                                }
                            )
                        )
                    }),
                ],
                header: SettingsListSectionHeader(title: "Dismiss Rule")
            )
        )
    }

    // MARK: - Interactions

    private func createInteractionsSection() -> SettingsListSection {
        .items(
            SettingsListItemsSection(
                items: [
                    .listItem(createActionItem(title: "Swipe to dismiss", id: "toast_swipe") {
                        ToastPresenter.showToast(
                            configuration: .warning(text: "Swipe me away")
                                .withSwipeToDismiss(true)
                        )
                    }),
                    .listItem(createActionItem(title: "Swipe + Nav bar", id: "toast_swipe_navbar") {
                        ToastPresenter.showToast(
                            configuration: .warning(text: "No internet connection")
                                .withPlacement(.navigationBar)
                                .withSwipeToDismiss(true)
                        )
                    }),
                    .listItem(createActionItem(title: "On tap callback", id: "toast_on_tap") {
                        var config = ToastPresenter.Configuration(
                            title: "Tap me!",
                            shape: .oval,
                            icon: .TKUIKit.Icons.Size16.checkmarkCircle,
                            iconTintColor: .Accent.green,
                            dismissRule: .none,
                            onTap: {
                                ToastPresenter.showToast(
                                    configuration: .confirmed(text: "Tapped!")
                                )
                            }
                        )
                        config.allowsSwipeToDismiss = true
                        ToastPresenter.showToast(configuration: config)
                    }),
                ],
                header: SettingsListSectionHeader(title: "Interactions")
            )
        )
    }

    // MARK: - Shape

    private func createShapeSection() -> SettingsListSection {
        .items(
            SettingsListItemsSection(
                items: [
                    .listItem(createActionItem(title: "Oval shape", id: "toast_shape_oval") {
                        ToastPresenter.showToast(
                            configuration: .init(
                                title: "Oval shape",
                                shape: .oval
                            )
                        )
                    }),
                    .listItem(createActionItem(title: "Rect shape", id: "toast_shape_rect") {
                        ToastPresenter.showToast(
                            configuration: .init(
                                title: "Rect shape",
                                shape: .rect
                            )
                        )
                    }),
                    .listItem(createActionItem(title: "Oval with icon", id: "toast_shape_oval_icon") {
                        ToastPresenter.showToast(
                            configuration: .init(
                                title: "Oval with icon",
                                shape: .oval,
                                icon: .TKUIKit.Icons.Size16.exclamationmarkTriangle,
                                iconTintColor: .Accent.orange
                            )
                        )
                    }),
                    .listItem(createActionItem(title: "Oval with activity", id: "toast_shape_oval_activity") {
                        ToastPresenter.showToast(
                            configuration: .init(
                                title: "Loading...",
                                shape: .oval,
                                isActivity: true,
                                dismissRule: .duration(4)
                            )
                        )
                    }),
                ],
                header: SettingsListSectionHeader(title: "Shape & Appearance")
            )
        )
    }

    // MARK: - Helpers

    private func createActionItem(
        title: String,
        id: String,
        action: @escaping () -> Void
    ) -> SettingsListItem {
        SettingsListItem(
            id: id,
            title: SettingsListItemTitle(title),
            onTap: { _ in
                action()
            }
        )
    }
}
