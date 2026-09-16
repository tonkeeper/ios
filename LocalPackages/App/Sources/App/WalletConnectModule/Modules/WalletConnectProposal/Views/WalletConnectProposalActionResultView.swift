import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct WalletConnectProposalActionResultView: View {
    enum State {
        case success
        case failure

        var title: String {
            switch self {
            case .success:
                TKLocales.Result.success
            case .failure:
                TKLocales.Result.failure
            }
        }

        var tintColor: TKColor {
            switch self {
            case .success:
                .accentGreen
            case .failure:
                .accentRed
            }
        }

        var icon: UIImage {
            switch self {
            case .success:
                .TKUIKit.Icons.Size32.checkmarkCircle
            case .failure:
                .TKUIKit.Icons.Size32.exclamationmarkCircle
            }
        }
    }

    let state: State

    var body: some View {
        VStack(spacing: Layout.spacing) {
            SwiftUI.Image(uiImage: state.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Layout.iconSize, height: Layout.iconSize)

            Text(state.title)
                .textStyle(.label2)
                .lineLimit(1)
        }
        .foregroundStyle(state.tintColor)
        .frame(maxWidth: .infinity, minHeight: Layout.height)
    }

    enum Layout {
        static let iconSize: CGFloat = 32
        static let spacing: CGFloat = 4
        static let height: CGFloat = 56
    }
}
