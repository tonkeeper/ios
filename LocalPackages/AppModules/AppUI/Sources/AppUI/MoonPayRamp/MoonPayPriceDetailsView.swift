import SwiftUI
import TKUIKit

/// What a MoonPay quote is made of, before paying: what is paid, the rate, each fee and what
/// arrives. It follows the quote on the Buy crypto screen, refreshes included.
public struct MoonPayPriceDetailsViewState: Equatable {
    public struct Row: Identifiable, Equatable {
        public var id: String
        public var title: String
        public var value: String

        public init(id: String, title: String, value: String) {
            self.id = id
            self.title = title
            self.value = value
        }
    }

    public var youPay: Row
    public var rateTitle: String
    public var rateText: String
    public var rateRestartToken: Int
    public var rateTimerDuration: TimeInterval
    public var fees: [Row]
    public var youGet: Row

    public init(
        youPay: Row,
        rateTitle: String,
        rateText: String,
        rateRestartToken: Int,
        rateTimerDuration: TimeInterval,
        fees: [Row],
        youGet: Row
    ) {
        self.youPay = youPay
        self.rateTitle = rateTitle
        self.rateText = rateText
        self.rateRestartToken = rateRestartToken
        self.rateTimerDuration = rateTimerDuration
        self.fees = fees
        self.youGet = youGet
    }
}

public struct MoonPayPriceDetailsView: View {
    private let state: MoonPayPriceDetailsViewState
    private let onToggleRateDirection: () -> Void

    public init(state: MoonPayPriceDetailsViewState, onToggleRateDirection: @escaping () -> Void) {
        self.state = state
        self.onToggleRateDirection = onToggleRateDirection
    }

    public var body: some View {
        VStack(spacing: 0) {
            row(state.youPay, showsDivider: true)
            rateRow
            ForEach(state.fees) { fee in
                row(fee, showsDivider: true)
            }
            row(state.youGet, showsDivider: false)
        }
        .asCellsGroup()
        .padding(.horizontal, Layout.horizontalInset)
        .padding(.bottom, Layout.bottomInset)
    }

    private func row(_ row: MoonPayPriceDetailsViewState.Row, showsDivider: Bool) -> some View {
        content(title: row.title, showsDivider: showsDivider) {
            Text(row.value)
                .textStyle(.body1)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
    }

    private var rateRow: some View {
        content(title: state.rateTitle, showsDivider: true) {
            HStack(spacing: Layout.rateSpacing) {
                CircularLoader(
                    preset: .xSmall,
                    duration: state.rateTimerDuration,
                    restartToken: state.rateRestartToken
                )
                Text(state.rateText)
                    .textStyle(.body1)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Button(action: onToggleRateDirection) {
                    SwiftUI.Image.TKUIKit.Icons.Size16.swap
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Layout.iconSize, height: Layout.iconSize)
                        .foregroundStyle(.iconTertiary)
                }
                .buttonStyle(TKTapAnimationButtonStyle())
                .contentShape(Rectangle().inset(by: -(Layout.hitSize - Layout.iconSize) / 2))
                .accessibilityLabel(state.rateText)
            }
        }
    }

    private func content(title: String, showsDivider: Bool, @ViewBuilder value: () -> some View) -> some View {
        HStack(spacing: Layout.rowSpacing) {
            Text(title)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 0)
            value()
        }
        .padding(.horizontal, Layout.rowInset)
        .frame(minHeight: Layout.rowHeight)
        .overlay(alignment: .bottom) {
            if showsDivider {
                TKColor.separatorCommon
                    .frame(height: Layout.dividerHeight)
                    .padding(.leading, Layout.rowInset)
            }
        }
    }
}

private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let bottomInset: CGFloat = 16
    static let rowInset: CGFloat = 16
    static let rowHeight: CGFloat = 67
    static let rowSpacing: CGFloat = 12
    static let rateSpacing: CGFloat = 6
    static let iconSize: CGFloat = 16
    static let hitSize: CGFloat = 44
    static let dividerHeight: CGFloat = 0.5
}
