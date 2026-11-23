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
    private let onCopy: (String) -> Void

    @State private var isFeesExpanded = false

    public init(
        state: MoonPayPaymentStatusViewState,
        onAction: @escaping () -> Void,
        onCopy: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.onAction = onAction
        self.onCopy = onCopy
    }

    public var body: some View {
        // The sheet draws the title and the close button.
        VStack(spacing: 0) {
            VStack(spacing: Layout.groupSpacing) {
                stepsGroup
                if state.showsDetails {
                    summaryGroup
                    feesGroup
                }
            }
            .padding(.bottom, Layout.contentBottomInset)

            if let actionTitle = state.actionTitle {
                ButtonView(config: .init(
                    title: actionTitle,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .primary,
                    action: onAction
                ))
                .padding(.horizontal, Layout.horizontalInset)
                .padding(.bottom, Layout.bottomInset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    private var stepsGroup: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.steps.enumerated()), id: \.element.id) { index, step in
                stepRow(step, isFirst: index == 0, isLast: index == state.steps.count - 1)
            }
        }
        .asCellsGroup()
    }

    /// The design's Cell / Status Step: a 44 pt indicator, a line to the steps around it, and a
    /// divider from the text.
    private func stepRow(_ step: MoonPayPaymentStatusViewState.Step, isFirst: Bool, isLast: Bool) -> some View {
        HStack(spacing: Layout.stepSpacing) {
            stepIndicator(step.status)
            VStack(alignment: .leading, spacing: 0) {
                Text(step.title)
                    .textStyle(.label1)
                    .foregroundStyle(step.status == .waiting ? .textSecondary : .textPrimary)
                    .lineLimit(1)
                Text(step.subtitle)
                    .textStyle(.body2)
                    .foregroundStyle(step.status == .waiting ? .textTertiary : .textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.horizontalInset)
        .frame(minHeight: Layout.stepHeight)
        .overlay(alignment: .topLeading) {
            if !isFirst {
                stepLine
            }
        }
        .overlay(alignment: .bottomLeading) {
            if !isLast {
                stepLine
            }
        }
        .overlay(alignment: .bottom) {
            if !isLast {
                TKColor.separatorCommon
                    .frame(height: Layout.dividerHeight)
                    .padding(.leading, Layout.dividerInset)
            }
        }
    }

    private var stepLine: some View {
        Capsule()
            .fill(.backgroundContentTint)
            .frame(width: Layout.lineWidth, height: Layout.lineHeight)
            .padding(.leading, Layout.horizontalInset + (Layout.indicatorSize - Layout.lineWidth) / 2)
    }

    private func stepIndicator(_ status: MoonPayPaymentStatusViewState.Step.Status) -> some View {
        ZStack {
            switch status {
            case .waiting:
                Circle().fill(.buttonTertiaryBackgroundDisabled)
            case .inProgress:
                Circle().fill(.backgroundContentTint)
                CircularLoader(mode: .indeterminate, preset: .medium)
            case .done:
                Circle().fill(.accentGreen.opacity(Layout.accentBackgroundOpacity))
                SwiftUI.Image.TKUIKit.Icons.Size28.checkmarkCircle
                    .renderingMode(.template)
                    .foregroundStyle(.accentGreen)
            case .failed:
                Circle().fill(.accentRed.opacity(Layout.accentBackgroundOpacity))
                SwiftUI.Image.TKUIKit.Icons.Size28.exclamationmarkCircle
                    .renderingMode(.template)
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
        .padding(.vertical, Layout.groupVerticalPadding)
        .asCellsGroup()
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
        HStack(spacing: Layout.rowSpacing) {
            Text(row.title)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .layoutPriority(1)
            Spacer(minLength: 0)
            Text(row.value)
                .textStyle(.body2)
                .foregroundStyle(row.isHighlighted ? .accentGreen : .textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, Layout.horizontalInset)
        .padding(.vertical, Layout.rowVerticalPadding)
    }

    private var feesGroup: some View {
        VStack(spacing: 0) {
            Button {
                guard !state.feeDetails.isEmpty else { return }
                isFeesExpanded.toggle()
            } label: {
                HStack(spacing: Layout.feesChevronSpacing) {
                    Text(state.feesTitle)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                    Spacer(minLength: Layout.rowSpacing)
                    Text(state.feesValue)
                        .textStyle(.body2)
                        .foregroundStyle(.textPrimary)
                    if !state.feeDetails.isEmpty {
                        SwiftUI.Image.TKUIKit.Icons.Size16.chevronDown
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: Layout.chevronSize, height: Layout.chevronSize)
                            .foregroundStyle(.iconSecondary)
                            .rotationEffect(.degrees(isFeesExpanded ? 180 : 0))
                    }
                }
                .padding(.horizontal, Layout.horizontalInset)
                .padding(.vertical, Layout.rowVerticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isFeesExpanded {
                ForEach(state.feeDetails) { row in
                    summaryRow(row)
                }
            }
        }
        .padding(.vertical, Layout.groupVerticalPadding)
        .asCellsGroup()
    }

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let groupSpacing: CGFloat = 8
        static let bottomInset: CGFloat = 16
        /// The design's 8 pt under the last group and the table's 16.
        static let contentBottomInset: CGFloat = 24
        static let stepHeight: CGFloat = 76
        static let stepSpacing: CGFloat = 16
        static let indicatorSize: CGFloat = 44
        static let accentBackgroundOpacity: Double = 0.12
        static let lineWidth: CGFloat = 2
        static let lineHeight: CGFloat = 12
        static let dividerInset: CGFloat = 76
        static let dividerHeight: CGFloat = 0.5
        static let groupVerticalPadding: CGFloat = 4
        static let rowVerticalPadding: CGFloat = 8
        static let rowSpacing: CGFloat = 8
        static let feesChevronSpacing: CGFloat = 6
        static let chevronSize: CGFloat = 16
    }
}
