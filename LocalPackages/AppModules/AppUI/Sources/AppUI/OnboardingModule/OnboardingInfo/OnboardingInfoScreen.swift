import SwiftUI
import TKUIKit

public struct OnboardingInfoScreen: View {
    public struct SkipAction {
        let title: String
        let action: () -> Void

        public init(title: String, action: @escaping () -> Void) {
            self.title = title
            self.action = action
        }
    }

    private let state: OnboardingInfoScreenState
    private let areActionsEnabled: Bool
    private let showsLoader: Bool
    private let onBack: (() -> Void)?
    private let skip: SkipAction?
    private let onContinue: () -> Void

    public init(
        state: OnboardingInfoScreenState,
        areActionsEnabled: Bool = true,
        showsLoader: Bool = false,
        onBack: (() -> Void)? = nil,
        skip: SkipAction? = nil,
        onContinue: @escaping () -> Void
    ) {
        self.state = state
        self.areActionsEnabled = areActionsEnabled
        self.showsLoader = showsLoader
        self.onBack = onBack
        self.skip = skip
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .fixedSize(horizontal: false, vertical: true)

            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        content
                        Spacer(minLength: 0)
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: geometry.size.height
                    )
                }
                .tkImmediateButtonPresses()
            }

            actionBar
        }
        .background(.backgroundPage)
        .navigationBarBackButtonHidden(true)
    }
}

private extension OnboardingInfoScreen {
    var header: some View {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                leftIcon: onBack.map { onBack in .back { _ in onBack() } },
                rightTextButton: skip.map { skip in
                    DefaultModalCardHeader.TextButton(title: skip.title, onTap: skip.action)
                },
                height: .compact
            )
        )
        .disabled(!areActionsEnabled)
    }

    var content: some View {
        VStack(spacing: 0) {
            if let icon = state.icon {
                Image(uiImage: icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(state.iconTintColor)
                    .frame(
                        width: Layout.iconWidth,
                        height: Layout.iconHeight
                    )
            }

            VStack(spacing: Layout.textSpacing) {
                Text(state.title)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)

                Text(state.subtitle)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Layout.textHorizontalPadding)
            .padding(.bottom, Layout.textBottomPadding)
        }
    }

    var actionBar: some View {
        ButtonView(
            config: ButtonView.Config(
                title: state.buttonTitle,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                showsLoader: showsLoader,
                action: onContinue
            )
        )
        .disabled(!areActionsEnabled)
        .padding(Layout.actionButtonPadding)
        .background(.backgroundTransparent, ignoresSafeAreaEdges: .bottom)
    }

    enum Layout {
        static let iconWidth: CGFloat = 128
        static let iconHeight: CGFloat = 144
        static let textSpacing: CGFloat = 3
        static let textBottomPadding: CGFloat = -2
        static let textHorizontalPadding: CGFloat = 32
        static let actionButtonPadding = EdgeInsets(
            top: 16,
            leading: 16,
            bottom: 16,
            trailing: 16
        )
    }
}
