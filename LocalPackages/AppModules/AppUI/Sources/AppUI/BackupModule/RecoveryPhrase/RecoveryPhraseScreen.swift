import SwiftUI
import TKUIKit

public struct RecoveryPhraseScreen: View {
    public enum HeaderButton {
        case back(() -> Void)
        case close(() -> Void)
    }

    private let state: RecoveryPhraseScreenState
    private let isWordsVisible: Bool
    private let headerButton: HeaderButton?
    private let onAction: (RecoveryPhraseScreenState.Action.ID) -> Void

    public init(
        state: RecoveryPhraseScreenState,
        isWordsVisible: Bool = true,
        headerButton: HeaderButton? = nil,
        onAction: @escaping (RecoveryPhraseScreenState.Action.ID) -> Void
    ) {
        self.state = state
        self.isWordsVisible = isWordsVisible
        self.headerButton = headerButton
        self.onAction = onAction
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    title

                    if let banner = state.banner {
                        RecoveryPhraseBannerView(text: banner)
                    }

                    RecoveryPhraseWordsView(words: state.words)
                        .opacity(isWordsVisible ? 1 : 0)
                        .animation(
                            .easeInOut(duration: Layout.wordsVisibilityAnimationDuration),
                            value: isWordsVisible
                        )
                        .padding(.horizontal, Layout.wordsHorizontalPadding)
                        .padding(.top, Layout.wordsTopPadding)
                        .padding(.bottom, Layout.wordsBottomPadding)
                }
            }
            .tkImmediateButtonPresses()

            actionBar
        }
        .background(.backgroundPage)
        .navigationBarBackButtonHidden(true)
    }
}

private extension RecoveryPhraseScreen {
    var header: some View {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                leftIcon: headerIcon,
                height: .compact
            )
        )
    }

    var headerIcon: DefaultModalCardHeader.Icon? {
        switch headerButton {
        case let .back(action):
            .back { _ in action() }
        case let .close(action):
            .close { _ in action() }
        case nil:
            nil
        }
    }

    var title: some View {
        VStack(spacing: Layout.titleSpacing) {
            Text(state.title)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)

            Text(state.caption)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Layout.titleHorizontalPadding)
        .padding(.top, Layout.titleTopPadding)
        .padding(.bottom, Layout.titleBottomPadding)
    }

    var actionBar: some View {
        VStack(spacing: Layout.actionSpacing) {
            ForEach(state.actions) { action in
                ButtonView(config: buttonConfig(for: action))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Layout.actionBarPadding)
        .background(.backgroundTransparent, ignoresSafeAreaEdges: .bottom)
    }

    func buttonConfig(for action: RecoveryPhraseScreenState.Action) -> ButtonView.Config {
        switch action.style {
        case .primary:
            ButtonView.Config(
                title: action.title,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                action: {
                    onAction(action.id)
                }
            )
        case .secondary:
            ButtonView.Config(
                title: action.title,
                size: .medium,
                appearance: .secondary,
                icon: action.icon.map {
                    ButtonView.Icon(image: $0)
                },
                action: {
                    onAction(action.id)
                }
            )
        }
    }

    enum Layout {
        static let titleSpacing: CGFloat = 4
        static let titleHorizontalPadding: CGFloat = 32
        static let titleTopPadding: CGFloat = 16
        static let titleBottomPadding: CGFloat = 12
        static let wordsHorizontalPadding: CGFloat = 32
        static let wordsTopPadding: CGFloat = 20
        static let wordsBottomPadding: CGFloat = 12
        static let wordsVisibilityAnimationDuration: TimeInterval = 0.2
        static let actionSpacing: CGFloat = 12
        static let actionBarPadding = EdgeInsets(
            top: 16,
            leading: 16,
            bottom: 16,
            trailing: 16
        )
    }
}

private struct RecoveryPhraseWordsView: View {
    let words: [RecoveryPhraseScreenState.Word]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            column(leftWords)
                .padding(.leading, Layout.leftColumnLeadingPadding)

            column(rightWords)
                .padding(.leading, Layout.rightColumnLeadingPadding)
                .padding(.trailing, Layout.rightColumnTrailingPadding)
        }
        .padding(.top, Layout.topPadding)
        .padding(.bottom, Layout.bottomPadding)
        .background(
            RoundedRectangle(
                cornerRadius: Layout.cornerRadius,
                style: .continuous
            )
            .fill(.backgroundContent)
        )
    }

    private var leftWords: ArraySlice<RecoveryPhraseScreenState.Word> {
        words.prefix(columnSize)
    }

    private var rightWords: ArraySlice<RecoveryPhraseScreenState.Word> {
        words.dropFirst(columnSize)
    }

    private var columnSize: Int {
        Int(ceil(Double(words.count) / 2))
    }

    private func column(_ words: ArraySlice<RecoveryPhraseScreenState.Word>) -> some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            ForEach(words) { word in
                RecoveryPhraseWordView(word: word)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    enum Layout {
        static let topPadding: CGFloat = 15
        static let bottomPadding: CGFloat = 17
        static let leftColumnLeadingPadding: CGFloat = 20
        static let rightColumnLeadingPadding: CGFloat = 16
        static let rightColumnTrailingPadding: CGFloat = 4
        static let rowSpacing: CGFloat = 8
        static let cornerRadius: CGFloat = 20
    }
}

private struct RecoveryPhraseWordView: View {
    let word: RecoveryPhraseScreenState.Word

    var body: some View {
        HStack(spacing: Layout.spacing) {
            Text("\(word.index).")
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .frame(width: Layout.indexWidth, alignment: .leading)

            Text(word.value)
                .textStyle(.body1)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(Layout.minimumScaleFactor)
                .accessibilityIdentifier("mnemonic.word.\(max(0, word.index - 1))")
        }
        .padding(.bottom, Layout.belowCentreNudge)
        .frame(height: Layout.height, alignment: .bottom)
    }

    enum Layout {
        static let height: CGFloat = 24
        static let belowCentreNudge: CGFloat = -2
        static let indexWidth: CGFloat = 24
        static let spacing: CGFloat = 2
        static let minimumScaleFactor: CGFloat = 0.75
    }
}

private struct RecoveryPhraseBannerView: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(.body3)
            .foregroundStyle(.constantBlack)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.accentOrange)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
    }
}
