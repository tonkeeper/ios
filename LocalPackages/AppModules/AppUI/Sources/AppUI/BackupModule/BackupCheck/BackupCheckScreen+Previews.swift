import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Backup check — empty") {
    backupCheckPreview(state: .preview)
}

@available(iOS 17.0, *)
#Preview("Backup check — selected") {
    backupCheckPreview(state: .previewSelected)
}

@available(iOS 17.0, *)
#Preview("Backup check — long words") {
    backupCheckPreview(state: .previewLongWords)
}

private func backupCheckPreview(state: BackupCheckScreenState) -> some View {
    BackupCheckScreen(
        state: state,
        onBack: {},
        onSelectOption: { _, _ in },
        onContinue: {}
    )
    .tkPreviewTheme(.deepBlue)
}

private extension BackupCheckScreenState {
    static let preview = BackupCheckScreenState(
        title: "Backup check",
        caption: "Let's see if you've got everything right. Choose words 7, 11, and 12.",
        buttonTitle: "Done",
        rows: [
            Row(id: 6, number: 7, options: ["address", "boat", "business"], selectedOption: nil),
            Row(id: 10, number: 11, options: ["air", "brother", "angry"], selectedOption: nil),
            Row(id: 11, number: 12, options: ["bless", "bicycle", "apple"], selectedOption: nil),
        ],
        isContinueEnabled: false,
        isError: false,
        failedAttemptCount: 0
    )

    static let previewSelected = BackupCheckScreenState(
        title: preview.title,
        caption: preview.caption,
        buttonTitle: preview.buttonTitle,
        rows: [
            Row(id: 6, number: 7, options: ["address", "boat", "business"], selectedOption: "business"),
            Row(id: 10, number: 11, options: ["air", "brother", "angry"], selectedOption: "brother"),
            Row(id: 11, number: 12, options: ["bless", "bicycle", "apple"], selectedOption: "bless"),
        ],
        isContinueEnabled: true,
        isError: false,
        failedAttemptCount: 0
    )

    static let previewLongWords = BackupCheckScreenState(
        title: preview.title,
        caption: "Let's see if you've got everything right. Choose words 6, 15, and 20.",
        buttonTitle: preview.buttonTitle,
        rows: [
            Row(id: 5, number: 6, options: ["exile", "name", "mushroom"], selectedOption: "mushroom"),
            Row(id: 14, number: 15, options: ["movement", "satisfy", "umbrella"], selectedOption: nil),
            Row(id: 19, number: 20, options: ["broom", "midnight", "mosquito"], selectedOption: nil),
        ],
        isContinueEnabled: false,
        isError: false,
        failedAttemptCount: 0
    )
}
