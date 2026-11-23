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
                    CircularLoader(mode: .indeterminate, preset: .custom(loaderConfiguration))
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

private extension BalanceHeaderBalanceStatusView {
    var loaderConfiguration: CircularLoaderConfiguration {
        CircularLoaderConfiguration(
            lineWidth: 2,
            progressColor: palette.icon.secondary,
            trackColor: palette.icon.secondary.opacity(0.32),
            size: CGSize(width: 12, height: 12),
            contentPadding: 1,
            spinnerArcLength: 0.25,
            spinnerTurnDuration: 1
        )
    }

    enum Layout {
        static let connectionSpacing: CGFloat = 4
        static let chevronSpacing: CGFloat = 4
    }
}
