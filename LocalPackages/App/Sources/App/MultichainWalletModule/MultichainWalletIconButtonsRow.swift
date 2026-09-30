import SwiftUI
import TKUIKit
import UIKit

struct MultichainWalletIconButtonsModel: Equatable {
    struct Item: Equatable {
        let title: String
        let kind: Kind
        let isEnabled: Bool

        enum Kind: Equatable {
            case send
            case deposit
            case swap
            case stake
        }
    }

    let send: Item
    let deposit: Item
    let swap: Item?
    let stake: Item?
}

struct MultichainWalletIconButtonsSection: View {
    enum Config {
        case shimmer
        case content(MultichainWalletIconButtonsModel)
    }

    let config: Config
    let onSend: () -> Void
    let onDeposit: () -> Void
    let onSwap: () -> Void
    let onStake: () -> Void

    var body: some View {
        section {
            switch config {
            case .shimmer:
                MultichainWalletIconButtonsRowSkeleton()
            case let .content(model):
                MultichainWalletIconButtonsRow(
                    model: model,
                    onSend: onSend,
                    onDeposit: onDeposit,
                    onSwap: onSwap,
                    onStake: onStake
                )
            }
        }
    }

    private func section<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
                .frame(height: Layout.rowHeight, alignment: .top)
                .clipped()
            Spacer(minLength: 0)
        }
        .frame(height: Layout.height, alignment: .top)
    }

    private enum Layout {
        static let height: CGFloat = 100
        static let rowHeight: CGFloat = 84
    }
}

struct MultichainWalletIconButtonsRowSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0 ..< Layout.buttonCount, id: \.self) { _ in
                IconButtonView(config: .shimmer(hasTitle: true))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private enum Layout {
        static let buttonCount = 4
    }
}

struct MultichainWalletIconButtonsRow: View {
    let model: MultichainWalletIconButtonsModel
    let onSend: () -> Void
    let onDeposit: () -> Void
    let onSwap: () -> Void
    let onStake: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            iconButton(model.send, action: onSend)
            iconButton(model.deposit, action: onDeposit)
            if let swap = model.swap {
                iconButton(swap, action: onSwap)
            }
            if let stake = model.stake {
                iconButton(stake, action: onStake)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func iconButton(_ item: MultichainWalletIconButtonsModel.Item, action: @escaping () -> Void) -> some View {
        IconButtonView(
            config: .content(
                IconButtonViewContent(
                    icon: item.kind.uiImage,
                    title: item.title
                )
            ),
            action: action
        )
        .disabled(!item.isEnabled)
    }
}

private extension MultichainWalletIconButtonsModel.Item.Kind {
    var uiImage: UIImage {
        switch self {
        case .send:
            .TKUIKit.Icons.Size28.arrowUpOutline
        case .deposit:
            .TKUIKit.Icons.Size28.arrowDownOutline
        case .swap:
            .TKUIKit.Icons.Size28.swapHorizontalOutline
        case .stake:
            .TKUIKit.Icons.Size28.stakingOutline
        }
    }
}
