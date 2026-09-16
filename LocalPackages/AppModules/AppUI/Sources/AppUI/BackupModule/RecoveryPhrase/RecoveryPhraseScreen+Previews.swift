import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Recovery phrase") {
    RecoveryPhraseScreen(
        state: .preview,
        headerButton: .back {},
        onAction: { _ in }
    )
    .tkPreviewTheme(.deepBlue)
}

private extension RecoveryPhraseScreenState {
    static let preview = RecoveryPhraseScreenState(
        title: "Back up your recovery phrase",
        caption: "Write down these words with their numbers and store them in a safe place.",
        words: [
            "blanket", "angry", "bottom", "bicycle", "air", "blanket",
            "business", "announce", "boat", "apple", "brother", "bless",
        ].enumerated().map {
            Word(index: $0.offset + 1, value: $0.element)
        },
        actions: [
            Action(
                id: "checkBackup",
                title: "Check Backup",
                style: .primary
            ),
        ]
    )
}
