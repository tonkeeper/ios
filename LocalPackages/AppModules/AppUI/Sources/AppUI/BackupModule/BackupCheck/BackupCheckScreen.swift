import SwiftUI
import TKUIKit
import UIKit

public struct BackupCheckScreen: View {
    @State private var shakeProgress: CGFloat = 0

    private let state: BackupCheckScreenState
    private let onBack: (() -> Void)?
    private let onSelectOption: (BackupCheckScreenState.Row.ID, String) -> Void
    private let onContinue: () -> Void

    public init(
        state: BackupCheckScreenState,
        onBack: (() -> Void)? = nil,
        onSelectOption: @escaping (BackupCheckScreenState.Row.ID, String) -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.state = state
        self.onBack = onBack
        self.onSelectOption = onSelectOption
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    title

                    VStack(spacing: Layout.rowSpacing) {
                        ForEach(state.rows) { row in
                            BackupCheckRowView(
                                row: row,
                                isError: state.isError,
                                onSelect: {
                                    onSelectOption(row.id, $0)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Layout.rowsHorizontalPadding)
                    .padding(.top, Layout.rowsTopPadding)
                    .padding(.bottom, Layout.rowsBottomPadding)
                    .modifier(ShakeEffect(progress: shakeProgress))
                }
            }
            .tkImmediateButtonPresses()

            actionBar
        }
        .background(.backgroundPage)
        .navigationBarBackButtonHidden(true)
        .onChange(of: state.failedAttemptCount) { failedAttemptCount in
            guard failedAttemptCount > 0 else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.linear(duration: Layout.shakeDuration)) {
                shakeProgress += 1
            }
        }
    }
}

private extension BackupCheckScreen {
    var header: some View {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                leftIcon: onBack.map { onBack in .back { _ in onBack() } },
                height: .compact
            )
        )
    }

    var title: some View {
        VStack(spacing: Layout.titleSpacing) {
            Text(state.title)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)

            Text(state.caption)
                .textStyle(.body1)
                .foregroundStyle(state.isError ? .accentRed : .textSecondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Layout.titleHorizontalPadding)
        .padding(.top, Layout.titleTopPadding)
        .padding(.bottom, Layout.titleBottomPadding)
    }

    var actionBar: some View {
        ButtonView(
            config: ButtonView.Config(
                title: state.buttonTitle,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                action: onContinue
            )
        )
        .disabled(!state.isContinueEnabled)
        .padding(Layout.actionBarPadding)
        .background(.backgroundTransparent, ignoresSafeAreaEdges: .bottom)
    }

    enum Layout {
        static let titleSpacing: CGFloat = 4
        static let titleHorizontalPadding: CGFloat = 32
        static let titleTopPadding: CGFloat = 16
        static let titleBottomPadding: CGFloat = 11
        static let rowsHorizontalPadding: CGFloat = 28
        static let rowsTopPadding: CGFloat = 20
        static let rowsBottomPadding: CGFloat = 12
        static let rowSpacing: CGFloat = 14
        static let shakeDuration: TimeInterval = 0.42
        static let actionBarPadding = EdgeInsets(
            top: 16,
            leading: 16,
            bottom: 16,
            trailing: 16
        )
    }
}

private struct ShakeEffect: GeometryEffect {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = Layout.amplitude * sin(progress * 2 * .pi * Layout.oscillations)
        return ProjectionTransform(
            CGAffineTransform(translationX: translation, y: 0)
        )
    }

    private enum Layout {
        static let amplitude: CGFloat = 10
        static let oscillations: CGFloat = 3
    }
}

private struct BackupCheckRowView: View {
    let row: BackupCheckScreenState.Row
    let isError: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(row.number).")
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, Layout.titleHorizontalPadding)
                .padding(.bottom, Layout.titleBottomPadding)

            HStack(spacing: Layout.buttonSpacing) {
                ForEach(row.options, id: \.self) { option in
                    optionButton(option)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func optionButton(_ option: String) -> some View {
        ButtonView(
            config: ButtonView.Config(
                title: option,
                size: .medium,
                layoutMode: .fill,
                appearance: .secondary,
                minimumTitleScaleFactor: Layout.titleMinimumScaleFactor,
                action: {
                    onSelect(option)
                }
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: Layout.buttonCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                borderColor(for: option),
                lineWidth: Layout.borderWidth
            )
        }
    }

    private func borderColor(for option: String) -> TKColor {
        guard row.selectedOption == option else {
            return .clear
        }
        return isError ? .fieldErrorBorder : .fieldActiveBorder
    }

    enum Layout {
        static let titleHorizontalPadding: CGFloat = 16
        static let titleBottomPadding: CGFloat = 6
        static let buttonSpacing: CGFloat = 6
        static let buttonCornerRadius: CGFloat = 24
        static let borderWidth: CGFloat = 1.5
        static let titleMinimumScaleFactor: CGFloat = 0.45
    }
}
