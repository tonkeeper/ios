import SwiftUI

private struct ChartBottomButtonPressedKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var chartBottomButtonIsPressed: Bool {
        get { self[ChartBottomButtonPressedKey.self] }
        set { self[ChartBottomButtonPressedKey.self] = newValue }
    }
}

public struct ChartBottomButtonsView: View {
    private let config: Config
    @Namespace private var selectedButtonNamespace

    public init(
        config: Config
    ) {
        self.config = config
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                switch config {
                case let .buttons(buttons):
                    ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                        ChartBottomButtonView(
                            config: button,
                            selectionNamespace: selectedButtonNamespace
                        )
                    }
                case let .shimmer(count):
                    HStack(spacing: 8) {
                        ForEach(0 ..< count, id: \.self) { _ in
                            ButtonView(
                                config: ButtonView.Config(
                                    title: " ",
                                    size: .small,
                                    layoutMode: .fill,
                                    appearance: .secondary,
                                    action: {}
                                )
                            )
                            .shimmer(true, config: .init(cornerRadius: .capsule))
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .animation(.easeInOut(duration: 0.2), value: selectedButtonIndex)
            .padding(Layout.contentInsets)
            Spacer(minLength: 0)
        }
        .frame(height: Layout.height)
    }

    private var selectedButtonIndex: Int? {
        guard case let .buttons(buttons) = config else {
            return nil
        }

        return buttons.firstIndex { $0.isSelected }
    }
}

private struct ChartBottomButtonView: View {
    let config: ChartBottomButtonsView.Config.Button
    let selectionNamespace: Namespace.ID

    @Environment(\.chartBottomButtonIsPressed) private var isPressed

    var body: some View {
        SwiftUI.Button(action: config.tapAction) {
            Text(config.title)
                .textStyle(.label2)
                .foregroundStyle(.buttonSecondaryForeground)
                .padding(.horizontal, Layout.horizontalPadding)
                .frame(height: Layout.height)
                .frame(maxWidth: .infinity)
                .background {
                    if config.isSelected {
                        Capsule()
                            .fill(
                                isPressed
                                    ? .buttonSecondaryBackgroundHighlighted
                                    : .buttonSecondaryBackground
                            )
                            .matchedGeometryEffect(
                                id: "selectedBackground",
                                in: selectionNamespace
                            )
                            .animation(.easeInOut(duration: 0.14), value: isPressed)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(ChartBottomButtonStyle())
    }

    private enum Layout {
        static let height: CGFloat = 36
        static let horizontalPadding: CGFloat = 16
    }
}

private struct ChartBottomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.chartBottomButtonIsPressed, configuration.isPressed)
            .tkTapAnimation(isPressed: configuration.isPressed, haptic: .soft)
    }
}

public extension ChartBottomButtonsView {
    enum Layout {
        static let height: CGFloat = 68

        static let contentInsets = EdgeInsets(
            top: 16,
            leading: 16,
            bottom: 0,
            trailing: 16
        )
    }

    enum Config {
        public struct Button {
            public let title: String
            public let isSelected: Bool
            public let tapAction: () -> Void

            public init(
                title: String,
                isSelected: Bool,
                tapAction: @escaping () -> Void
            ) {
                self.title = title
                self.isSelected = isSelected
                self.tapAction = tapAction
            }
        }

        case buttons([Button])
        case shimmer(count: Int)
    }
}
