import SwiftUI
import TKUIKit
import UIKit

struct RaffleSwapPromoView: View {
    let title: String

    @State private var sweepOffset: CGFloat = -Layout.minBandWidth
    @State private var sweepTask: Task<Void, Never>?

    var body: some View {
        label
            .overlay {
                GeometryReader { proxy in
                    shine(width: proxy.size.width)
                        .onAppear { startSweeping(width: proxy.size.width) }
                }
            }
            .mask { label }
            .fixedSize()
            .onDisappear {
                sweepTask?.cancel()
                sweepTask = nil
            }
    }

    private var label: some View {
        HStack(spacing: Layout.iconTextSpacing) {
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size24.flash)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .foregroundStyle(Self.gradientStart)

            Text(title)
                .textStyle(.label2)
                .foregroundStyle(Self.textGradient)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func shine(width: CGFloat) -> some View {
        let bandWidth = max(width * Layout.bandWidthRatio, Layout.minBandWidth)
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .white.opacity(0), location: 0),
                .init(color: .white.opacity(Layout.shineOpacity), location: 0.5),
                .init(color: .white.opacity(0), location: 1),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: bandWidth)
        .offset(x: sweepOffset)
        .blendMode(.plusLighter)
    }

    private func startSweeping(width: CGFloat) {
        guard sweepTask == nil else { return }
        let bandWidth = max(width * Layout.bandWidthRatio, Layout.minBandWidth)
        let travel = width + bandWidth * 2
        sweepOffset = -bandWidth
        sweepTask = Task { @MainActor in
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: Layout.sweepDuration)) {
                    sweepOffset = -bandWidth + travel
                }
                try? await Task.sleep(nanoseconds: UInt64(Layout.period * 1_000_000_000))
                guard !Task.isCancelled else { return }
                sweepOffset = -bandWidth
            }
        }
    }
}

private extension RaffleSwapPromoView {
    static let gradientStart = Color(red: Double(0x24) / 255, green: Double(0xA6) / 255, blue: Double(0xFE) / 255)
    static let gradientEnd = Color(red: Double(0xB0) / 255, green: Double(0xDF) / 255, blue: Double(0xFF) / 255)

    static let textGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: gradientStart, location: 0),
            .init(color: gradientEnd, location: 0.784),
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )

    enum Layout {
        static let iconSize: CGFloat = 16
        static let iconTextSpacing: CGFloat = 2
        static let bandWidthRatio: CGFloat = 0.35
        static let minBandWidth: CGFloat = 28
        static let shineOpacity: CGFloat = 0.85
        static let period: TimeInterval = 3
        static let sweepDuration: TimeInterval = 1
    }
}
