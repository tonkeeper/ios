import SwiftUI
import TKLocalize
import TKUIKit

/// Takes the confirm slider's place once the swap quote fails to refresh: the reason first, then a
/// way to ask again, as the Android confirmation does it.
public struct MultichainSwapConfirmationQuoteFailureView: View {
    private let message: String
    private let onRetry: () -> Void

    @State private var showsRetry: Bool

    public init(message: String, onRetry: @escaping () -> Void) {
        self.init(message: message, showsRetry: false, onRetry: onRetry)
    }

    init(message: String, showsRetry: Bool, onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
        _showsRetry = State(initialValue: showsRetry)
    }

    public var body: some View {
        ZStack {
            if showsRetry {
                ButtonView(
                    config: ButtonView.Config(
                        title: TKLocales.Actions.tryAgain,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .primary,
                        icon: ButtonView.Icon(image: .TKUIKit.Icons.Size16.refresh),
                        action: onRetry
                    )
                )
                .transition(.opacity)
            } else {
                VStack(spacing: Layout.messageSpacing) {
                    SwiftUI.Image.TKUIKit.Icons.Size32.exclamationmarkCircle
                        .renderingMode(.template)
                        .foregroundStyle(.accentRed)
                    Text(message)
                        .textStyle(.label2)
                        .foregroundStyle(.accentRed)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: message) { _ in
            showsRetry = false
        }
        .task(id: message) {
            try? await Task.sleep(nanoseconds: Layout.messageDuration)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: Layout.fadeDuration)) {
                showsRetry = true
            }
        }
    }

    private enum Layout {
        static let messageSpacing: CGFloat = 4
        static let messageDuration: UInt64 = 2_000_000_000
        static let fadeDuration: TimeInterval = 0.4
    }
}
