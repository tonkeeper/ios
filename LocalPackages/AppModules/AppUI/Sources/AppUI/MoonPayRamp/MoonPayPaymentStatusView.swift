import SwiftUI
import TKUIKit

public struct MoonPayPaymentStatusViewState: Equatable {
    public var title: String
    public var steps: [Step]
    public var summary: [SummaryRow]
    public var feesTitle: String
    public var feesValue: String
    public var feeDetails: [SummaryRow]
    public var showsDetails: Bool
    public var actionTitle: String?

    public struct Step: Identifiable, Equatable {
        public enum Status: Equatable {
            case waiting
            case inProgress
            case done
            case failed
        }

        public var id: String
        public var title: String
        public var subtitle: String
        public var status: Status

        public init(id: String, title: String, subtitle: String, status: Status) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.status = status
        }
    }

    public struct SummaryRow: Identifiable, Equatable {
        public var id: String
        public var title: String
        public var value: String
        public var isHighlighted: Bool
        public var isCopyable: Bool

        public init(id: String, title: String, value: String, isHighlighted: Bool = false, isCopyable: Bool = false) {
            self.id = id
            self.title = title
            self.value = value
            self.isHighlighted = isHighlighted
            self.isCopyable = isCopyable
        }
    }

    public init(
        title: String,
        steps: [Step],
        summary: [SummaryRow],
        feesTitle: String,
        feesValue: String,
        feeDetails: [SummaryRow],
        showsDetails: Bool = true,
        actionTitle: String?
    ) {
        self.title = title
        self.steps = steps
        self.summary = summary
        self.feesTitle = feesTitle
        self.feesValue = feesValue
        self.feeDetails = feeDetails
        self.showsDetails = showsDetails
        self.actionTitle = actionTitle
    }
}

public struct MoonPayPaymentStatusView: View {
    private let state: MoonPayPaymentStatusViewState
    private let onAction: () -> Void
    private let onClose: () -> Void
    private let onCopy: (String) -> Void

    @State private var isFeesExpanded = false

    public init(
        state: MoonPayPaymentStatusViewState,
        onAction: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onCopy: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.onAction = onAction
        self.onClose = onClose
        self.onCopy = onCopy
    }

    public var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: DefaultModalCardHeader.Config(
                    title: DefaultModalCardHeader.Title(text: state.title),
                    rightIcon: .close(onTap: { _ in onClose() }),
                    height: .compact
                )
            )
            .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Layout.groupSpacing) {
                    stepsGroup
                    if state.showsDetails {
                        summaryGroup
                        feesGroup
                    }
                }
                .padding(.horizontal, Layout.horizontalInset)
                .padding(.top, Layout.groupSpacing)
            }

            if let actionTitle = state.actionTitle {
                ButtonView(config: .init(
                    title: actionTitle,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .primary,
                    action: onAction
                ))
                .padding(.horizontal, Layout.horizontalInset)
                .padding(.vertical, Layout.groupSpacing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    private var stepsGroup: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.steps.enumerated()), id: \.element.id) { index, step in
                stepRow(step, isLast: index == state.steps.count - 1)
            }
        }
        .padding(.vertical, Layout.stepsVerticalPadding)
        .background(RoundedRectangle(cornerRadius: Layout.cornerRadius).fill(.backgroundContent))
    }

    private func stepRow(_ step: MoonPayPaymentStatusViewState.Step, isLast: Bool) -> some View {
        HStack(alignment: .center, spacing: 16) {
            stepIndicator(step.status)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .textStyle(.label1)
                    .foregroundStyle(step.status == .waiting ? .textSecondary : .textPrimary)
                Text(step.subtitle)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, Layout.stepRowPadding)
    }

    private func stepIndicator(_ status: MoonPayPaymentStatusViewState.Step.Status) -> some View {
        ZStack {
            switch status {
            case .waiting:
                Circle().fill(.backgroundContentTint)
            case .inProgress:
                Circle().fill(.backgroundContentTint)
                ProgressView()
            case .done:
                Circle().fill(.accentGreen.opacity(0.2))
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.accentGreen)
            case .failed:
                Circle().fill(.accentRed.opacity(0.2))
                Image(systemName: "exclamationmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.accentRed)
            }
        }
        .frame(width: Layout.indicatorSize, height: Layout.indicatorSize)
    }

    private var summaryGroup: some View {
        VStack(spacing: 0) {
            ForEach(state.summary) { row in
                summaryRow(row)
            }
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: Layout.cornerRadius).fill(.backgroundContent))
    }

    @ViewBuilder
    private func summaryRow(_ row: MoonPayPaymentStatusViewState.SummaryRow) -> some View {
        if row.isCopyable {
            Button(action: { onCopy(row.value) }) {
                summaryRowContent(row)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
        } else {
            summaryRowContent(row)
        }
    }

    private func summaryRowContent(_ row: MoonPayPaymentStatusViewState.SummaryRow) -> some View {
        HStack {
            Text(row.title)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .layoutPriority(1)
            Spacer(minLength: 8)
            Text(row.value)
                .textStyle(.body2)
                .foregroundStyle(row.isHighlighted ? .accentGreen : .textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var feesGroup: some View {
        VStack(spacing: 0) {
            Button {
                guard !state.feeDetails.isEmpty else { return }
                isFeesExpanded.toggle()
            } label: {
                HStack {
                    Text(state.feesTitle)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                    Spacer(minLength: 8)
                    Text(state.feesValue)
                        .textStyle(.body2)
                        .foregroundStyle(.textPrimary)
                    if !state.feeDetails.isEmpty {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.iconTertiary)
                            .rotationEffect(.degrees(isFeesExpanded ? 180 : 0))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isFeesExpanded {
                ForEach(state.feeDetails) { row in
                    summaryRow(row)
                }
            }
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: Layout.cornerRadius).fill(.backgroundContent))
    }

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let groupSpacing: CGFloat = 16
        static let cornerRadius: CGFloat = 16
        static let indicatorSize: CGFloat = 48
        static let stepsVerticalPadding: CGFloat = 4
        static let stepRowPadding: CGFloat = 8
    }
}
