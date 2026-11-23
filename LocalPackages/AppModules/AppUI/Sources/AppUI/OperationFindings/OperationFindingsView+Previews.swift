import OperationReviewModels
import SwiftUI
import TKUIKit

private extension OperationReview {
    static let previewDanger = OperationReview(id: "danger", findings: [
        OperationFinding(
            id: "overspend",
            kind: "Overspend",
            severity: .danger,
            title: "Spends more than shown",
            details: "100 USDC instead of 10 USDC",
            subject: "0x3B4D794a66304F130a4Db8F2551B0070dfCf5ca7"
        ),
        OperationFinding(
            id: "recipient",
            kind: "ForeignRecipient",
            severity: .warning,
            title: "Sends to another address",
            subject: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
        ),
        OperationFinding(id: "info", kind: "Info", severity: .info, title: "Never shown"),
    ])

    static let previewWarning = OperationReview(id: "warning", findings: [
        OperationFinding(
            id: "approval",
            kind: "Approval",
            severity: .warning,
            title: "Approves spending",
            details: "Unlimited USDC",
            subject: "0x3B4D794a66304F130a4Db8F2551B0070dfCf5ca7"
        ),
    ])

    static let previewLongList = OperationReview(id: "long", findings: [
        OperationFinding(
            id: "overspend",
            kind: "Overspend",
            severity: .danger,
            title: "Spends more than shown",
            details: "1,250 USDT instead of 125 USDT",
            subject: "0xdAC17F958D2ee523a2206206994597C13D831ec7"
        ),
        OperationFinding(
            id: "delegate",
            kind: "ForeignDelegate",
            severity: .danger,
            title: "Hands over control of your account",
            subject: "0x24b576BC271823bF9C24BE627B4363b9b00191e9"
        ),
        OperationFinding(
            id: "recipient",
            kind: "ForeignRecipient",
            severity: .warning,
            title: "Sends to another address",
            subject: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
        ),
        OperationFinding(id: "blind", kind: "BlindCall", severity: .warning, title: "Calls a contract the wallet can't read"),
        OperationFinding(
            id: "allowance",
            kind: "LongAllowance",
            severity: .warning,
            title: "Leaves a long-lived allowance",
            details: "Unlimited USDT",
            subject: "0x3B4D794a66304F130a4Db8F2551B0070dfCf5ca7"
        ),
        OperationFinding(id: "nonce", kind: "DurableNonce", severity: .warning, title: "Never expires"),
    ])
}

#Preview("Danger") {
    OperationFindingsView(review: .previewDanger, onConfirm: {}, onCancel: {})
        .tkPreviewTheme(.deepBlue)
}

#Preview("Warning") {
    OperationFindingsView(review: .previewWarning, onConfirm: {}, onCancel: {})
        .tkPreviewTheme(.light)
}

#Preview("Long list") {
    OperationFindingsView(review: .previewLongList, onConfirm: {}, onCancel: {})
        .tkPreviewTheme(.dark)
}
