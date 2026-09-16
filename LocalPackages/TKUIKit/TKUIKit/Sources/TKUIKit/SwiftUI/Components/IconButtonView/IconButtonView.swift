import SwiftUI

public enum IconButtonViewConfig: Hashable {
    case content(IconButtonViewContent)
    case shimmer(hasTitle: Bool)
}

public struct IconButtonViewContent: Hashable {
    public var icon: UIImage
    public var title: String?
    public var appearance: ButtonView.Appearance
    public var size: IconButtonView.Size

    public init(
        icon: UIImage,
        title: String? = nil,
        appearance: ButtonView.Appearance = .icon,
        size: IconButtonView.Size = .regular
    ) {
        self.icon = icon
        self.title = title
        self.appearance = appearance
        self.size = size
    }
}

public struct IconButtonView: View {
    public enum Size: Hashable {
        case regular
        case large
    }

    let config: IconButtonViewConfig
    private let action: (() -> Void)?

    public init(
        config: IconButtonViewConfig,
        action: (() -> Void)? = nil
    ) {
        self.config = config
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) {
                IconButtonViewContentView(config: config)
            }
            .buttonStyle(IconButtonStateStyle())
        } else {
            IconButtonViewContentView(config: config)
        }
    }
}

private struct IconButtonStateStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let state: ButtonView.State = if isEnabled {
            configuration.isPressed ? .highlighted : .normal
        } else {
            .disabled
        }

        configuration.label
            .environment(\.modernButtonState, state)
            .animation(.easeInOut(duration: 0.14), value: state)
            .tkTapAnimation(isPressed: configuration.isPressed, haptic: .light)
    }
}

private struct IconButtonViewContentView: View {
    let config: IconButtonViewConfig

    @Environment(\.modernButtonState) private var state
    @Environment(\.tkPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            iconView
                .clipShape(Circle())
                .padding(iconContainerInsets)
            titleView
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch config {
        case let .content(content):
            Image(uiImage: content.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    content.appearance.iconColor(for: state, palette: palette)
                )
                .frame(
                    width: Layout.iconSize,
                    height: Layout.iconSize
                )
                .padding(iconInsets)
                .background(
                    Circle()
                        .fill(
                            content.appearance.backgroundColor(for: state, palette: palette)
                        )
                )
        case .shimmer:
            ShimmerSwiftUIView()
                .frame(
                    width: [
                        Layout.iconInsets.leading,
                        Layout.iconSize,
                        Layout.iconInsets.trailing,
                    ].reduce(0, +),
                    height: [
                        Layout.iconInsets.top,
                        Layout.iconSize,
                        Layout.iconInsets.bottom,
                    ].reduce(0, +)
                )
        }
    }

    @ViewBuilder
    private var titleView: some View {
        switch config {
        case let .content(content):
            if let title = content.title {
                Text(title)
                    .textStyle(Layout.titleTextStyle)
                    .foregroundStyle(
                        content.appearance.textColor(for: state, palette: palette)
                    )
                    .frame(maxWidth: width, alignment: .center)
                    .padding(.bottom, Layout.titleBottomPadding)
                    .padding(.bottom, Layout.titleContainerBottomPadding)
            }
        case let .shimmer(hasTitle):
            if hasTitle {
                ShimmerSwiftUIView(
                    config: ShimmerSwiftUIView.Config(
                        cornerRadius: .capsule
                    )
                )
                .frame(width: 60, height: Layout.titleTextStyle.lineHeight)
                .padding(.bottom, Layout.titleContainerBottomPadding)
            }
        }
    }

    private var iconInsets: EdgeInsets {
        switch config {
        case let .content(content):
            content.size.iconInsets
        case .shimmer:
            Layout.iconInsets
        }
    }

    private var iconContainerInsets: EdgeInsets {
        switch config {
        case let .content(content):
            content.size.iconContainerInsets
        case .shimmer:
            Layout.iconContainerInsets
        }
    }

    private var width: CGFloat {
        switch config {
        case let .content(content):
            content.size.width
        case .shimmer:
            Layout.width
        }
    }
}

private extension IconButtonView.Size {
    var iconInsets: EdgeInsets {
        switch self {
        case .regular:
            Layout.iconInsets
        case .large:
            EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        }
    }

    var iconContainerInsets: EdgeInsets {
        switch self {
        case .regular:
            Layout.iconContainerInsets
        case .large:
            EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        }
    }

    var width: CGFloat {
        switch self {
        case .regular:
            Layout.width
        case .large:
            Layout.largeBackgroundSize
        }
    }
}

private enum Layout {
    static let iconSize: CGFloat = 28
    static let iconInsets = EdgeInsets(
        top: 8,
        leading: 8,
        bottom: 8,
        trailing: 8
    )
    static let iconContainerInsets = EdgeInsets(
        top: 8,
        leading: 16,
        bottom: 8,
        trailing: 16
    )
    static let titleTextStyle: TKTextStyle = .label3
    static let titleBottomPadding: CGFloat = 2
    static let titleContainerBottomPadding: CGFloat = 8
    static let largeBackgroundSize: CGFloat = 56

    static var width: CGFloat {
        [
            iconContainerInsets.leading,
            iconInsets.leading,
            iconSize,
            iconInsets.trailing,
            iconContainerInsets.trailing,
        ].reduce(0, +)
    }
}
