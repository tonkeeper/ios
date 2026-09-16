import SwiftUI

public struct CellTrailingAccessory: View {
    private let config: Config

    public init(config: Config) {
        self.config = config
    }

    public var body: some View {
        config.icon
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(
                width: config.iconSize,
                height: config.iconSize
            )
            .foregroundStyle(config.color)
            .padding(config.contentInsets)
    }
}

extension CellTrailingAccessory {
    enum Layout {
        static let insets = EdgeInsets(
            top: 0,
            leading: 0,
            bottom: 0,
            trailing: 16
        )
    }
}

public extension CellTrailingAccessory {
    struct Config {
        public var color: TKColor
        public var iconSize: CGFloat
        public var icon: Image
        public var contentInsets: EdgeInsets

        public init(
            color: TKColor,
            icon: Image,
            iconSize: CGFloat = 28,
            contentInsetsModifier: (inout EdgeInsets) -> Void = { _ in }
        ) {
            self.color = color
            self.icon = icon
            self.iconSize = iconSize
            self.contentInsets = {
                var insets = Layout.insets
                contentInsetsModifier(&insets)
                return insets
            }()
        }
    }
}
