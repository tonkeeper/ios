import SwiftUI
import TKLocalize
import TKUIKit

public struct BackupSafetyCheckView: View {
    @Environment(\.tkPalette) private var palette
    @State private var isConfirmed: Bool

    private let onContinue: () -> Void

    public init(onContinue: @escaping () -> Void) {
        self.init(isConfirmed: false, onContinue: onContinue)
    }

    init(isConfirmed: Bool, onContinue: @escaping () -> Void) {
        _isConfirmed = State(initialValue: isConfirmed)
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            rules
            confirmation
            actionBar
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
        .ignoresSafeArea(.container, edges: .top)
    }
}

private extension BackupSafetyCheckView {
    var header: some View {
        VStack(spacing: 0) {
            SwiftUI.Image.TKUIKit.Icons.Size84.exclamationmarkCircle
                .renderingMode(.template)
                .foregroundStyle(.accentOrange)
                .padding(.bottom, Layout.iconBottomInset)

            Text(TKLocales.Backup.SafetyCheck.title)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Layout.titleHorizontalInset)
        }
        .padding(.bottom, Layout.headerBottomInset)
    }

    var rules: some View {
        VStack(spacing: 0) {
            ForEach(Self.rules, id: \.self) { rule in
                BackupSafetyCheckRuleView(text: rule)
            }
        }
        .padding(.vertical, Layout.rulesVerticalInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.backgroundContent)
        .clipShape(
            RoundedRectangle(
                cornerRadius: Layout.cardCornerRadius,
                style: .continuous
            )
        )
        .padding(.horizontal, Layout.horizontalInset)
        .padding(.top, Layout.rulesTopInset)
        .padding(.bottom, Layout.rulesBottomInset)
    }

    var confirmation: some View {
        Button {
            isConfirmed.toggle()
        } label: {
            HStack(alignment: .top, spacing: Layout.confirmationSpacing) {
                CheckboxView(isSelected: isConfirmed)

                confirmationText
                    .textStyle(.body2)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Layout.confirmationTextVerticalInset)
            }
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .padding(Layout.confirmationPadding)
        .background(.backgroundContent)
        .clipShape(
            RoundedRectangle(
                cornerRadius: Layout.cardCornerRadius,
                style: .continuous
            )
        )
        .padding(.horizontal, Layout.horizontalInset)
        .padding(.bottom, Layout.confirmationBottomInset)
    }

    var confirmationText: Text {
        let highlighted = TKLocales.Backup.SafetyCheck.Agreement.highlighted
        let text = TKLocales.Backup.SafetyCheck.Agreement.text(highlighted)
        guard let range = text.range(of: highlighted) else {
            return Text(text)
        }
        return Text(String(text[text.startIndex ..< range.lowerBound]))
            + Text(highlighted).foregroundColor(palette.accent.orange)
            + Text(String(text[range.upperBound...]))
    }

    var actionBar: some View {
        ButtonView(
            config: .init(
                title: TKLocales.Backup.ShowPhrase.title,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                action: onContinue
            )
        )
        .disabled(!isConfirmed)
        .padding([.top, .leading, .trailing], Layout.horizontalInset)
        .padding(.bottom, Layout.bottomInset)
    }

    static let rules = [
        TKLocales.Backup.SafetyCheck.List.item1,
        TKLocales.Backup.SafetyCheck.List.item2,
        TKLocales.Backup.SafetyCheck.List.item3,
    ]

    enum Layout {
        static let horizontalInset: CGFloat = 16
        static let iconBottomInset: CGFloat = 11
        static let titleHorizontalInset: CGFloat = 32
        static let headerBottomInset: CGFloat = 14
        static let rulesVerticalInset: CGFloat = 12
        static let rulesTopInset: CGFloat = 8
        static let rulesBottomInset: CGFloat = 16
        static let cardCornerRadius: CGFloat = 16
        static let confirmationSpacing: CGFloat = 12
        static let confirmationPadding: CGFloat = 16
        static let confirmationTextVerticalInset: CGFloat = 1
        static let confirmationBottomInset: CGFloat = 16
        static let bottomInset: CGFloat = 3
    }
}

private struct BackupSafetyCheckRuleView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Layout.contentSpacing) {
            Text("\u{2022}")
                .textStyle(.body2)
                .foregroundStyle(.textPrimary)
                .frame(width: Layout.bulletWidth, alignment: .leading)

            Text(text)
                .textStyle(.body2)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, Layout.leadingInset)
        .padding(.trailing, Layout.trailingInset)
        .padding(.top, Layout.topInset)
        .padding(.bottom, Layout.bottomInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum Layout {
        static let bulletWidth: CGFloat = 8
        static let contentSpacing: CGFloat = 5
        static let leadingInset: CGFloat = 20
        static let trailingInset: CGFloat = 16
        static let topInset: CGFloat = 7
        static let bottomInset: CGFloat = 6
    }
}
