import SwiftUI
import TKUIKit
import UIKit

struct WalletContainerTopBarModel {
    struct IconButton {
        let icon: UIImage
        let action: () -> Void
    }

    let walletButton: WalletButtonConfig
    let walletButtonAction: () -> Void
    let scanButton: IconButton
    let historyButton: IconButton
    let settingsButton: IconButton
    let isSettingsIndicatorVisible: Bool
}

final class WalletContainerTopBarState: ObservableObject {
    @Published var model: WalletContainerTopBarModel?
    @Published private(set) var isSeparatorHidden = true

    private(set) var historyButtonAnchorView: UIView?
    private var historyButtonAnchorViewObservers: [(UIView) -> Void] = []

    private(set) var walletButtonAnchorView: UIView?
    private var walletButtonAnchorViewObservers: [(UIView) -> Void] = []

    func setSeparatorHidden(_ isHidden: Bool) {
        guard isSeparatorHidden != isHidden else { return }
        isSeparatorHidden = isHidden
    }

    func resolveHistoryButtonAnchorView(_ view: UIView) {
        historyButtonAnchorView = view
        guard !historyButtonAnchorViewObservers.isEmpty else { return }
        let observers = historyButtonAnchorViewObservers
        historyButtonAnchorViewObservers = []
        observers.forEach { $0(view) }
    }

    func waitForHistoryButtonAnchorView(_ completion: @escaping (UIView) -> Void) {
        if let historyButtonAnchorView {
            completion(historyButtonAnchorView)
        } else {
            historyButtonAnchorViewObservers.append(completion)
        }
    }

    func resolveWalletButtonAnchorView(_ view: UIView) {
        walletButtonAnchorView = view
        guard !walletButtonAnchorViewObservers.isEmpty else { return }
        let observers = walletButtonAnchorViewObservers
        walletButtonAnchorViewObservers = []
        observers.forEach { $0(view) }
    }

    func waitForWalletButtonAnchorView(_ completion: @escaping (UIView) -> Void) {
        if let walletButtonAnchorView {
            completion(walletButtonAnchorView)
        } else {
            walletButtonAnchorViewObservers.append(completion)
        }
    }
}

struct WalletContainerTopBarView: View {
    @ObservedObject var state: WalletContainerTopBarState

    var body: some View {
        Group {
            if let model = state.model {
                content(model)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Layout.height)
        .background {
            TKColor.backgroundPage
                .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            if !state.isSeparatorHidden {
                TKColor.separatorCommon
                    .frame(height: TKUIKit.Constants.separatorWidth)
            }
        }
    }

    private func content(_ model: WalletContainerTopBarModel) -> some View {
        ZStack {
            HStack(spacing: 0) {
                IndicatorButtonView(
                    config: IndicatorButtonView.Config(
                        icon: model.scanButton.icon,
                        haptic: .light,
                        action: model.scanButton.action
                    )
                )

                Spacer(minLength: 0)

                IndicatorButtonView(
                    config: IndicatorButtonView.Config(
                        icon: model.historyButton.icon,
                        haptic: .light,
                        action: model.historyButton.action
                    )
                )
                .overlay {
                    AnchorViewResolver { view in
                        state.resolveHistoryButtonAnchorView(view)
                    }
                }

                IndicatorButtonView(
                    config: IndicatorButtonView.Config(
                        icon: model.settingsButton.icon,
                        showsIndicator: model.isSettingsIndicatorVisible,
                        haptic: .light,
                        action: model.settingsButton.action
                    )
                )
            }
            .padding(.horizontal, Layout.buttonsHorizontalInset)

            WalletButton(
                config: model.walletButton,
                haptic: .none,
                action: model.walletButtonAction
            )
            .padding(.horizontal, Layout.walletButtonHorizontalInset)
            .overlay {
                AnchorViewResolver { view in
                    state.resolveWalletButtonAnchorView(view)
                }
            }
        }
    }
}

private extension WalletContainerTopBarView {
    enum Layout {
        static let height: CGFloat = 64
        static let buttonsHorizontalInset: CGFloat = 8
        static let walletButtonHorizontalInset: CGFloat = 104
    }
}
