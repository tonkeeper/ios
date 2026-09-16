import SwiftUI

public struct BalanceHeaderBalanceStatusViewConfig: Hashable {
    public enum State: Hashable {
        case address(String, tags: [TKTagSwiftUIViewConfig], showsChevron: Bool = false)
        case updated(String)
        case connection(ConnectionStatus)
    }

    public struct ConnectionStatus: Hashable {
        public var title: String
        public var titleColor: TKColor
        public var isLoading: Bool

        public init(
            title: String,
            titleColor: TKColor = .textSecondary,
            isLoading: Bool
        ) {
            self.title = title
            self.titleColor = titleColor
            self.isLoading = isLoading
        }
    }

    public var state: State

    public init(state: State) {
        self.state = state
    }
}

struct BalanceHeaderBalanceStatusView: View {
    @Environment(\.tkPalette) private var palette

    var config: BalanceHeaderBalanceStatusViewConfig
    private let action: (() -> Void)?
    private let longPressAction: (() -> Void)?

    init(
        config: BalanceHeaderBalanceStatusViewConfig,
        action: (() -> Void)? = nil,
        longPressAction: (() -> Void)? = nil
    ) {
        self.config = config
        self.action = action
        self.longPressAction = longPressAction
    }

    var body: some View {
        if let longPressAction {
            SwiftUI.Button(action: {}) {
                content
            }
            .buttonStyle(BalanceHeaderBalanceStatusSwiftUIViewStyle())
            .simultaneousGesture(
                TapGesture()
                    .exclusively(before: LongPressGesture())
                    .onEnded { value in
                        switch value {
                        case .first:
                            action?()
                        case .second:
                            longPressAction()
                        }
                    }
            )
        } else {
            SwiftUI.Button(action: {
                action?()
            }) {
                content
            }
            .buttonStyle(BalanceHeaderBalanceStatusSwiftUIViewStyle())
        }
    }
}

private extension BalanceHeaderBalanceStatusView {
    @ViewBuilder
    var content: some View {
        switch config.state {
        case let .address(text, tags, showsChevron):
            HStack(spacing: 0) {
                label(text)

                ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                    TKTagSwiftUIView(config: tag)
                }

                if showsChevron {
                    SwiftUI.Image.TKUIKit.Icons.Size16.switch
                        .renderingMode(.template)
                        .foregroundStyle(.textSecondary)
                        .padding(.leading, Layout.chevronSpacing)
                }
            }
            .frame(maxWidth: .infinity)
        case let .updated(text):
            label(text)
                .frame(maxWidth: .infinity)
        case let .connection(model):
            HStack(spacing: Layout.connectionSpacing) {
                Text(model.title)
                    .textStyle(.body2)
                    .foregroundStyle(model.titleColor)
                    .multilineTextAlignment(.center)

                if model.isLoading {
                    BalanceHeaderBalanceStatusLoaderView(
                        size: Layout.loaderSize,
                        tintColor: palette.icon.secondary
                    )
                    .frame(
                        width: Layout.loaderSize.side,
                        height: Layout.loaderSize.side
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    func label(_ text: String) -> some View {
        Text(text)
            .textStyle(.body2)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .multilineTextAlignment(.center)
    }
}

private struct BalanceHeaderBalanceStatusSwiftUIViewStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .tkTapAnimation(isPressed: configuration.isPressed)
    }
}

private struct BalanceHeaderBalanceStatusLoaderView: View {
    var size: Size
    var tintColor: Color
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    tintColor.opacity(Layout.bottomCircleOpacity),
                    lineWidth: size.circleWidth
                )
                .frame(
                    width: size.circleSide,
                    height: size.circleSide
                )

            Circle()
                .trim(from: 0, to: Layout.topCircleTrimEnd)
                .stroke(
                    tintColor,
                    style: StrokeStyle(
                        lineWidth: size.circleWidth,
                        lineCap: .round
                    )
                )
                .frame(
                    width: size.circleSide,
                    height: size.circleSide
                )
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: Layout.rotationDuration)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .frame(
            width: size.side,
            height: size.side
        )
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

private extension BalanceHeaderBalanceStatusView {
    enum Layout {
        static let connectionSpacing: CGFloat = 4
        static let chevronSpacing: CGFloat = 4
        static let loaderSize: BalanceHeaderBalanceStatusLoaderView.Size = .xSmall
    }
}

private extension BalanceHeaderBalanceStatusLoaderView {
    enum Size {
        case xSmall

        var side: CGFloat {
            switch self {
            case .xSmall:
                12
            }
        }

        var circleSide: CGFloat {
            switch self {
            case .xSmall:
                10
            }
        }

        var circleWidth: CGFloat {
            switch self {
            case .xSmall:
                2
            }
        }
    }

    enum Layout {
        static let bottomCircleOpacity: CGFloat = 0.32
        static let topCircleTrimEnd: CGFloat = 0.25
        static let rotationDuration: TimeInterval = 1
    }
}
