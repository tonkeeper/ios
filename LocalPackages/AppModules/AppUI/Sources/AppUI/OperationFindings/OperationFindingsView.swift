import OperationReviewModels
import SwiftUI
import TKLocalize
import TKUIKit

/// What a review found in an operation, put to the user before it is signed: its warnings and
/// dangers, never its info.
struct OperationFindingsView: View {
    private let review: OperationReview
    let onConfirm: () -> Void
    let onCancel: () -> Void

    init(review: OperationReview, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.review = review
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            findings
            ButtonView(config: .init(
                title: TKLocales.OperationValidation.confirmAnyway,
                size: .large,
                layoutMode: .fill,
                appearance: isDanger ? .primaryDestructive : .primaryAttention,
                action: onConfirm
            ))
            .accessibilityIdentifier("operation_findings_confirm")
            ButtonView(config: .init(
                title: TKLocales.Actions.cancel,
                size: .large,
                layoutMode: .fill,
                appearance: .secondary,
                action: onCancel
            ))
            .accessibilityIdentifier("operation_findings_cancel")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(.backgroundPage)
    }
}

private extension OperationFindingsView {
    var isDanger: Bool {
        review.severity == .danger
    }

    var header: some View {
        VStack(spacing: 16) {
            (isDanger ? Image.TKUIKit.Icons.Size84.exclamationmarkTriangle : Image.TKUIKit.Icons.Size84.exclamationmarkCircle)
                .renderingMode(.template)
                .foregroundStyle(isDanger ? .accentRed : .accentOrange)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(isDanger ? TKLocales.OperationValidation.dangerTitle : TKLocales.OperationValidation.warningTitle)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)
                Text(TKLocales.OperationValidation.description)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
            }
            .multilineTextAlignment(.center)
        }
    }

    var findings: some View {
        VStack(spacing: 0) {
            ForEach(review.findings.filter { $0.severity > .info }) { finding in
                row(finding)
            }
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    func row(_ finding: OperationFinding) -> some View {
        HStack(alignment: .top, spacing: 12) {
            (finding.severity == .danger ? Image.TKUIKit.Icons.Size28.exclamationmarkTriangle : Image.TKUIKit.Icons.Size28.exclamationmarkCircle)
                .renderingMode(.template)
                .foregroundStyle(.iconSecondary)
                .padding(8)
                .background(.backgroundContentTint)
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(finding.title)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                if let details = finding.details {
                    Text(details)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                }
                if let subject = finding.subject {
                    Text(subject)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}
