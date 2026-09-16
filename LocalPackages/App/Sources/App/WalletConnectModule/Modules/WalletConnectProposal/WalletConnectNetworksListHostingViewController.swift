import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

final class WalletConnectNetworksListHostingViewController: TKHostingController<WalletConnectNetworksListScreen> {
    init(chains: [WalletConnectProposalChainItem]) {
        super.init(content: WalletConnectNetworksListScreen(chains: chains))
        configurePresentation()
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        presentationController?.delegate = self
    }
}

private extension WalletConnectNetworksListHostingViewController {
    func configurePresentation() {
        modalPresentationStyle = .pageSheet

        guard let sheetPresentationController else {
            return
        }

        sheetPresentationController.detents = [.large()]
        sheetPresentationController.prefersGrabberVisible = false
        sheetPresentationController.prefersScrollingExpandsWhenScrolledToEdge = false
    }
}

extension WalletConnectNetworksListHostingViewController: UIAdaptivePresentationControllerDelegate {}

struct WalletConnectNetworksListScreen: View {
    @Environment(\.dismiss) private var dismiss
    let chains: [WalletConnectProposalChainItem]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    networksList
                        .padding(.bottom, Layout.scrollBottomPadding)
                }
                .tkImmediateButtonPresses()
            }

            actionBar
        }
        .background(.backgroundPage)
    }
}

private extension WalletConnectNetworksListScreen {
    var header: some View {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                title: DefaultModalCardHeader.Title(text: TKLocales.WalletConnect.Proposal.networksToConnect),
                rightIcon: .close(
                    onTap: { _ in
                        dismiss()
                    }
                ),
                height: .atLeast(Layout.headerHeight)
            )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    var networksList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(chains.enumerated()), id: \.element.id) { index, item in
                WalletConnectChainCell(
                    content: item.cellContent,
                    showsDivider: index < chains.count - 1
                )
            }
        }
        .asCellsGroup()
    }

    var actionBar: some View {
        VStack(spacing: 0) {
            ButtonView(
                config: ButtonView.Config(
                    title: TKLocales.Actions.ok,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .secondary,
                    action: {
                        dismiss()
                    }
                )
            )
            .padding(Layout.actionButtonPadding)
        }
        .background(.backgroundPage.opacity(0.96), ignoresSafeAreaEdges: .bottom)
    }

    enum Layout {
        static let headerHeight: CGFloat = 64
        static let scrollBottomPadding: CGFloat = 96
        static let actionButtonPadding = EdgeInsets(top: 16, leading: 16, bottom: 18, trailing: 16)
    }
}
