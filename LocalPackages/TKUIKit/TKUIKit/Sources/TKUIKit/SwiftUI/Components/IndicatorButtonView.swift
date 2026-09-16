import SwiftUI
import UIKit

public struct IndicatorButtonView: View {
    public struct Config {
        public var icon: UIImage
        public var iconColor: TKColor
        public var showsIndicator: Bool
        public var haptic: TKTapAnimationHaptic
        public var action: () -> Void

        public init(
            icon: UIImage,
            iconColor: TKColor = .iconSecondary,
            showsIndicator: Bool = false,
            haptic: TKTapAnimationHaptic = .none,
            action: @escaping () -> Void
        ) {
            self.icon = icon
            self.iconColor = iconColor
            self.showsIndicator = showsIndicator
            self.haptic = haptic
            self.action = action
        }
    }

    private let config: Config

    public init(config: Config) {
        self.config = config
    }

    public var body: some View {
        Button(action: config.action) {
            Image(uiImage: config.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(config.iconColor)
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .overlay(alignment: .topTrailing) {
                    if config.showsIndicator {
                        Circle()
                            .fill(.accentRed)
                            .frame(width: Layout.indicatorSize, height: Layout.indicatorSize)
                            .offset(x: Layout.indicatorOffset)
                    }
                }
                .padding(Layout.contentPadding)
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: config.haptic))
    }
}

private enum Layout {
    static let iconSize: CGFloat = 28
    static let contentPadding: CGFloat = 10
    static let indicatorSize: CGFloat = 6
    static let indicatorOffset: CGFloat = 6
}
