import PerpsModels
import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsChartPeriodRow: View {
    @Environment(\.tkResolvedTheme) private var resolvedTheme
    let timeframe: PerpsChartTimeframe
    let mode: PerpsChartMode
    let onSelectTimeframe: (PerpsChartTimeframe) -> Void
    let onSelectMode: (PerpsChartMode) -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(PerpsChartTimeframe.allCases, id: \.self, content: timeframeChip)
                }
                .padding(.leading, Layout.leadingPadding)
                .padding(.trailing, Layout.trailingPadding)
            }
            .frame(height: Layout.chipHeight)
            .overlay(alignment: .trailing) {
                Color.clear
                    .frame(width: Layout.scrimWidth)
                    .tkScrim(.backgroundPage, edge: .trailing)
                    .allowsHitTesting(false)
            }
            modeToggle
                .padding(.trailing, Layout.toggleTrailingPadding)
        }
        .frame(height: Layout.height)
    }

    private func timeframeChip(_ value: PerpsChartTimeframe) -> some View {
        let isSelected = value == timeframe
        return Button(action: { onSelectTimeframe(value) }) {
            Text(value.localizedLabel)
                .textStyle(.label2)
                .foregroundStyle(.buttonSecondaryForeground)
                .frame(width: Layout.chipWidth, height: Layout.chipHeight)
                .background(Capsule().fill(isSelected ? .buttonSecondaryBackground : .clear))
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeTab(.candle, icon: .TKUIKit.Icons.Size16.chartCandle)
            modeTab(.line, icon: .TKUIKit.Icons.Size16.chartLine)
        }
        .padding(Layout.togglePadding)
        .background(Capsule().fill(.backgroundContent))
        .shadow(color: .constantBlack.opacity(0.12), radius: 8, y: 4)
        .shadow(color: .constantBlack.opacity(0.24), radius: 32, y: 16)
    }

    private func modeTab(_ value: PerpsChartMode, icon: Image) -> some View {
        let isSelected = value == mode
        return Button(action: { onSelectMode(value) }) {
            icon
                .renderingMode(.template)
                .foregroundStyle(isSelected ? .iconPrimary : .iconSecondary)
                .frame(width: Layout.tabSide, height: Layout.tabSide)
                .background(Circle().fill(isSelected ? selectedTabBackground : .clear))
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var selectedTabBackground: TKColor {
        resolvedTheme == .light ? .backgroundContentTint : .backgroundContentAttention
    }
}

private extension PerpsChartTimeframe {
    var localizedLabel: String {
        switch self {
        case .m1: return TKLocales.Perps.Chart.timeframe1m
        case .m5: return TKLocales.Perps.Chart.timeframe5m
        case .m15: return TKLocales.Perps.Chart.timeframe15m
        case .h1: return TKLocales.Perps.Chart.timeframe1h
        case .h4: return TKLocales.Perps.Chart.timeframe4h
        case .h12: return TKLocales.Perps.Chart.timeframe12h
        case .d1: return TKLocales.Perps.Chart.timeframe1d
        }
    }
}

private enum Layout {
    static let height: CGFloat = 68
    static let leadingPadding: CGFloat = 16
    static let trailingPadding: CGFloat = 92
    static let chipWidth: CGFloat = 56
    static let chipHeight: CGFloat = 36
    static let scrimWidth: CGFloat = 38
    static let toggleTrailingPadding: CGFloat = 20
    static let togglePadding: CGFloat = 4
    static let tabSide: CGFloat = 32
}
