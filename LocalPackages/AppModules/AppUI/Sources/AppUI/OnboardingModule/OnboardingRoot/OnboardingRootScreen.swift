import SwiftUI
import TKUIKit

public struct OnboardingRootScreen: View {
    private let state: OnboardingRootScreenState
    private let onCreate: () -> Void
    private let onImport: () -> Void

    /// What sits between the mark and the bottom edge and cannot give up height. Measured rather
    /// than derived from `Layout`, because it depends on how the copy wraps.
    @State private var rigidContentHeight: CGFloat = 0

    public init(
        state: OnboardingRootScreenState,
        onCreate: @escaping () -> Void,
        onImport: @escaping () -> Void
    ) {
        self.state = state
        self.onCreate = onCreate
        self.onImport = onImport
    }

    public var body: some View {
        GeometryReader { proxy in
            let scale = spacingScale(in: proxy)

            VStack(spacing: 0) {
                BrandLogo()
                    .padding(.top, BrandLogo.topInset(in: proxy))

                textPart(spacingScale: scale)
                    .padding(.top, Layout.logoBottomPadding * scale)

                Spacer(minLength: Layout.captionBottomPadding * scale)

                actionBarView(in: proxy, spacingScale: scale)
            }
            .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
        }
        .onPreferenceChange(RigidHeightKey.self) { rigidContentHeight = $0 }
        .background(alignment: .top) {
            OnboardingRootBackground()
        }
        .background(.backgroundPage)
        .ignoresSafeArea(.keyboard)
    }
}

private extension OnboardingRootScreen {
    func spacingScale(in proxy: GeometryProxy) -> CGFloat {
        let available = proxy.size.height
            - BrandLogo.topInset(in: proxy)
            - BrandLogo.size
            - rigidContentHeight
        return min(1, max(0, available / Layout.designedSpacing))
    }

    func textPart(spacingScale: CGFloat) -> some View {
        VStack(spacing: Layout.titleCaptionSpacing * spacingScale) {
            Text(state.title)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
                .measuringRigidHeight()

            Text(state.caption)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .measuringRigidHeight()
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Layout.horizontalPadding)
    }

    func actionBarView(in geometry: GeometryProxy, spacingScale: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: Layout.buttonSpacing) {
                ButtonView(
                    config: ButtonView.Config(
                        title: state.createButtonTitle,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .primary,
                        action: onCreate
                    )
                )

                ButtonView(
                    config: ButtonView.Config(
                        title: state.importButtonTitle,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .secondary,
                        action: onImport
                    )
                )
            }
            .measuringRigidHeight()

            termsView(in: geometry)
                .padding(.top, Layout.termsTopPadding * spacingScale)
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }

    func termsView(in geometry: GeometryProxy) -> some View {
        Text(termsText)
            .textStyle(.body2)
            .foregroundStyle(.textTertiary)
            .tint(.accentBlue)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, bottomPadding(in: geometry))
            .measuringRigidHeight()
    }

    func bottomPadding(in geometry: GeometryProxy) -> CGFloat {
        max(
            Layout.termsBottomPadding,
            Layout.termsMinBottomInset - geometry.safeAreaInsets.bottom
        )
    }

    var termsText: AttributedString {
        var text = AttributedString(state.termsCaption)
        guard
            let url = state.termsURL,
            let range = text.range(of: state.termsLinkTitle)
        else {
            return text
        }
        text[range].link = url
        return text
    }

    enum Layout {
        static let horizontalPadding: CGFloat = 32
        static let titleCaptionSpacing: CGFloat = 4
        static let logoBottomPadding: CGFloat = 33
        static let captionBottomPadding: CGFloat = 47
        static let buttonSpacing: CGFloat = 16
        static let termsTopPadding: CGFloat = 31
        static let termsBottomPadding: CGFloat = 3
        static let termsMinBottomInset: CGFloat = 16

        static let designedSpacing = logoBottomPadding
            + titleCaptionSpacing
            + captionBottomPadding
            + termsTopPadding
    }
}

private struct RigidHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

private extension View {
    func measuringRigidHeight() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: RigidHeightKey.self, value: proxy.size.height)
            }
        )
    }
}
