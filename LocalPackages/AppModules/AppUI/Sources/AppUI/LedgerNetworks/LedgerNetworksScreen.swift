import SwiftUI
import TKLocalize
import TKUIKit

public struct LedgerNetworksScreen: View {
    private let state: LedgerNetworksScreenState
    private let headerIcon: DefaultModalCardHeader.Icon?
    private let onToggle: (String) -> Void
    private let onContinue: () -> Void

    public init(
        state: LedgerNetworksScreenState,
        headerIcon: DefaultModalCardHeader.Icon?,
        onToggle: @escaping (String) -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.state = state
        self.headerIcon = headerIcon
        self.onToggle = onToggle
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(config: DefaultModalCardHeader.Config(leftIcon: headerIcon, height: .compact))
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: Layout.sectionSpacing) {
                    title
                    apps
                }
                .padding(.horizontal, Layout.horizontalInset)
                .padding(.bottom, Layout.horizontalInset)
            }

            ButtonView(
                config: ButtonView.Config(
                    title: TKLocales.Actions.continueAction,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .primary,
                    action: onContinue
                )
            )
            .disabled(!state.isContinueEnabled)
            .padding(.horizontal, Layout.horizontalInset)
            .padding(.bottom, Layout.buttonBottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension LedgerNetworksScreen {
    var title: some View {
        VStack(spacing: Layout.titleSpacing) {
            Text(state.title)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
            Text(state.description)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.titleHorizontalInset)
    }

    var apps: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.apps.enumerated()), id: \.element.id) { index, app in
                if index > 0 {
                    separator
                }
                LedgerAppRow(app: app) {
                    onToggle(app.id)
                }
            }
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
    }

    var separator: some View {
        Rectangle()
            .fill(.separatorCommon)
            .frame(height: Layout.separatorHeight)
            .padding(.leading, Layout.separatorInset)
    }
}

private struct LedgerAppRow: View {
    let app: LedgerNetworksScreenState.App
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Layout.iconSpacing) {
                Image(uiImage: app.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                Text(app.title)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: 0)
                CheckboxView(isSelected: app.isSelected)
            }
            .padding(Layout.rowInset)
            .contentShape(Rectangle())
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .disabled(app.isRequired)
    }

    private enum Layout {
        static let rowInset: CGFloat = 16
        static let iconSize: CGFloat = 28
        static let iconSpacing: CGFloat = 12
    }
}

private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let titleSpacing: CGFloat = 4
    static let titleHorizontalInset: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let separatorInset: CGFloat = 16
    static let separatorHeight: CGFloat = 0.5
    static let buttonBottomInset: CGFloat = 16
}
