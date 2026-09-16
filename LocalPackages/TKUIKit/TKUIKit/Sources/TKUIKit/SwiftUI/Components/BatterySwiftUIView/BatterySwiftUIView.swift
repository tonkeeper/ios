import SwiftUI

public struct BatterySwiftUIViewConfig: Hashable {
    public enum Size: Hashable {
        case size24
        case size34
        case size44
        case size52
        case size128
    }

    public enum State: Hashable {
        case fill(CGFloat)
        case emptyTinted
        case empty
        /// Charges taken back by a refund left the service balance below zero.
        case negative
    }

    public struct Padding: Hashable {
        public static let zero = Padding()

        public var top: CGFloat
        public var leading: CGFloat
        public var bottom: CGFloat
        public var trailing: CGFloat

        public init(
            top: CGFloat = 0,
            leading: CGFloat = 0,
            bottom: CGFloat = 0,
            trailing: CGFloat = 0
        ) {
            self.top = top
            self.leading = leading
            self.bottom = bottom
            self.trailing = trailing
        }
    }

    public var size: Size
    public var state: State
    public var padding: Padding

    public init(
        size: Size,
        state: State = .empty,
        padding: Padding = .zero
    ) {
        self.size = size
        self.state = state
        self.padding = padding
    }
}

public struct BatterySwiftUIView: View {
    @Environment(\.tkPalette) private var palette

    public var config: BatterySwiftUIViewConfig

    public init(config: BatterySwiftUIViewConfig) {
        self.config = config
    }

    public var body: some View {
        contentView
            .frame(
                width: config.size.bodySize.width,
                height: config.size.bodySize.height
            )
            .padding(config.padding.edgeInsets)
            .frame(
                width: config.size.bodySize.width + config.padding.leading + config.padding.trailing,
                height: config.size.bodySize.height + config.padding.top + config.padding.bottom
            )
    }
}

private extension BatterySwiftUIView {
    var contentView: some View {
        ZStack {
            Image(uiImage: config.size.bodyImage)
                .resizable()
                .frame(
                    width: config.size.bodySize.width,
                    height: config.size.bodySize.height
                )

            flashView

            fillView
        }
    }

    @ViewBuilder
    var flashView: some View {
        if let flashImage = config.size.flashImage {
            Image(uiImage: flashImage)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(config.state.flashColor(palette))
                .frame(
                    width: config.size.flashSize.width,
                    height: config.size.flashSize.height
                )
                .opacity(config.state.flashOpacity)
                .offset(y: config.size.bodySize.height * 0.05)
                .animation(.easeInOut(duration: 0.2), value: config.state)
        }
    }

    var fillView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            RoundedRectangle(
                cornerRadius: config.size.fillCornerRadius,
                style: .continuous
            )
            .fill(config.state.fillColor(palette))
            .frame(height: fillHeight)
            .opacity(config.state.fillOpacity)
            .padding(.leading, config.size.fillInsets.leading)
            .padding(.trailing, config.size.fillInsets.trailing)
            .padding(.bottom, config.size.fillInsets.bottom)
        }
        .frame(
            width: config.size.bodySize.width,
            height: config.size.bodySize.height
        )
        .animation(.easeOut(duration: 0.2), value: config.state)
    }

    var fillHeight: CGFloat {
        switch config.state {
        case let .fill(fill):
            config.size.fillMaximumHeight * min(1, max(fill, 0.2))
        case .emptyTinted, .empty, .negative:
            0
        }
    }
}

private extension BatterySwiftUIViewConfig.Size {
    var bodyImage: UIImage {
        switch self {
        case .size24:
            .TKUIKit.Icons.Size24.batteryBody
        case .size34:
            .TKUIKit.Icons.Size34.batteryBody
        case .size44:
            .TKUIKit.Icons.Size44.batteryBody
        case .size52:
            .TKUIKit.Icons.Size52.batteryBody
        case .size128:
            .TKUIKit.Icons.Size128.batteryBody
        }
    }

    var bodySize: CGSize {
        switch self {
        case .size24:
            CGSize(width: 14, height: 24)
        case .size34:
            CGSize(width: 20, height: 34)
        case .size44:
            CGSize(width: 26, height: 44)
        case .size52:
            CGSize(width: 34, height: 52)
        case .size128:
            CGSize(width: 68, height: 114)
        }
    }

    var flashImage: UIImage? {
        switch self {
        case .size24:
            nil
        case .size34:
            .TKUIKit.Icons.Size16.batteryFlash
        case .size44:
            .TKUIKit.Icons.Size16.batteryFlash
        case .size52:
            nil
        case .size128:
            .TKUIKit.Icons.Size16.batteryFlash
        }
    }

    var flashSize: CGSize {
        switch self {
        case .size24:
            .zero
        case .size34:
            CGSize(width: 9, height: 13)
        case .size44:
            CGSize(width: 9, height: 13)
        case .size52:
            .zero
        case .size128:
            CGSize(width: 28, height: 40)
        }
    }

    var fillCornerRadius: CGFloat {
        switch self {
        case .size24:
            1.5
        case .size34:
            2
        case .size44:
            3.5
        case .size52:
            5
        case .size128:
            8
        }
    }

    var fillMaximumHeight: CGFloat {
        switch self {
        case .size24:
            18
        case .size34:
            25
        case .size44:
            34
        case .size52:
            38
        case .size128:
            88
        }
    }

    var fillInsets: BatterySwiftUIViewConfig.Padding {
        switch self {
        case .size24:
            BatterySwiftUIViewConfig.Padding(top: 0, leading: 2, bottom: 2, trailing: 2)
        case .size34:
            BatterySwiftUIViewConfig.Padding(top: 0, leading: 3, bottom: 3, trailing: 3)
        case .size44:
            BatterySwiftUIViewConfig.Padding(top: 0, leading: 3, bottom: 3, trailing: 3)
        case .size52:
            BatterySwiftUIViewConfig.Padding(top: 9, leading: 4, bottom: 5, trailing: 4)
        case .size128:
            BatterySwiftUIViewConfig.Padding(top: 0, leading: 8, bottom: 8, trailing: 8)
        }
    }
}

private extension BatterySwiftUIViewConfig.State {
    var flashOpacity: CGFloat {
        switch self {
        case .fill:
            0
        case .emptyTinted, .empty, .negative:
            1
        }
    }

    func flashColor(_ palette: TKPalette) -> Color {
        switch self {
        case .fill:
            .clear
        case .emptyTinted:
            palette.accent.blue
        case .empty:
            palette.icon.secondary
        case .negative:
            palette.accent.red
        }
    }

    var fillOpacity: CGFloat {
        switch self {
        case .fill:
            1
        case .emptyTinted, .empty, .negative:
            0
        }
    }

    func fillColor(_ palette: TKPalette) -> Color {
        switch self {
        case let .fill(fill):
            fill <= 0.1 ? palette.accent.orange : palette.accent.blue
        case .emptyTinted, .empty, .negative:
            palette.accent.orange
        }
    }
}

private extension BatterySwiftUIViewConfig.Padding {
    var edgeInsets: EdgeInsets {
        EdgeInsets(
            top: top,
            leading: leading,
            bottom: bottom,
            trailing: trailing
        )
    }
}
