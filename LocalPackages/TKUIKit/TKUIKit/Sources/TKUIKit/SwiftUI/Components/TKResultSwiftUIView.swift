import SwiftUI
import UIKit

/// SwiftUI counterpart of `TKResultView`: an action's outcome in its action bar, an icon over a
/// title of up to two lines in the outcome's color.
public struct TKResultSwiftUIView: View {
    public enum State {
        case success
        case failure
    }

    private let state: State
    private let title: String

    public init(state: State, title: String) {
        self.state = state
        self.title = title
    }

    public var body: some View {
        VStack(spacing: Layout.spacing) {
            SwiftUI.Image(uiImage: state.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Layout.iconSize, height: Layout.iconSize)
            Text(title)
                .textStyle(.label2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(state.color)
        .accessibilityElement(children: .combine)
    }
}

private extension TKResultSwiftUIView {
    enum Layout {
        static let iconSize: CGFloat = 32
        static let spacing: CGFloat = 4
    }
}

private extension TKResultSwiftUIView.State {
    var icon: UIImage {
        switch self {
        case .success:
            .TKUIKit.Icons.Size32.checkmarkCircle
        case .failure:
            .TKUIKit.Icons.Size32.exclamationmarkCircle
        }
    }

    var color: TKColor {
        switch self {
        case .success:
            .accentGreen
        case .failure:
            .accentRed
        }
    }
}
