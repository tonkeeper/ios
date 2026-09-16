import SwiftUI
import UIKit

private struct QRCodeRippleTuningPreview: View {
    @State private var duration = QrCodeRippleConfiguration.default.animationDuration
    @State private var ringWidthModules = Double(QrCodeRippleConfiguration.default.ringWidthInModules)
    @State private var activeTapRadiusModules = Double(
        QrCodeRippleConfiguration.default.activeTapRadiusInModules
    )
    @State private var maximumDotDiameterShrink = Double(QrCodeRippleConfiguration.default.maxDotDiameterReduction)
    @State private var maximumFinderPatternDiameterShrink = Double(
        QrCodeRippleConfiguration.default.maxFinderPatternOpacityReduction
    )
    @State private var maximumActiveRippleCount = QrCodeRippleConfiguration.default.maxSimultaniousRipplesCount
    @State private var centerCutoutEnabled = true

    private let matrix = PreviewQrCodeMatrix.sample

    var body: some View {
        VStack(spacing: 24) {
            QrCodeView(
                matrix: matrix,
                configuration: QrCodeGeneratorConfiguration(
                    centerCutoutSize: centerCutoutEnabled ? CGSize(width: 68, height: 68) : nil
                ),
                rippleConfiguration: rippleConfiguration
            ) {
                if centerCutoutEnabled {
                    centerOverlay
                }
            }
            .frame(width: 280, height: 280)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            controls
        }
        .padding(24)
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }

    private var rippleConfiguration: QrCodeRippleConfiguration {
        QrCodeRippleConfiguration(
            animationDuration: duration,
            ringWidthInModules: CGFloat(ringWidthModules),
            activeTapRadiusInModules: CGFloat(activeTapRadiusModules),
            maxDotDiameterReduction: CGFloat(maximumDotDiameterShrink),
            maxFinderPatternOpacityReduction: CGFloat(maximumFinderPatternDiameterShrink),
            maxSimultaniousRipplesCount: maximumActiveRippleCount
        )
    }

    private var centerOverlay: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 52, height: 52)

            Text("TK")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
        }
        .allowsHitTesting(false)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            tuningSlider(
                title: "Duration",
                value: $duration,
                range: 0.25 ... 5,
                valueText: String(format: "%.2fs", duration)
            )

            tuningSlider(
                title: "Ring width",
                value: $ringWidthModules,
                range: 0.75 ... 5,
                valueText: String(format: "%.2f modules", ringWidthModules)
            )

            tuningSlider(
                title: "Tap shrink area",
                value: $activeTapRadiusModules,
                range: 0.75 ... 8,
                valueText: String(format: "%.2f modules", activeTapRadiusModules)
            )

            tuningSlider(
                title: "Dot shrink",
                value: $maximumDotDiameterShrink,
                range: 0 ... 0.5,
                valueText: String(format: "-%.0f%%", maximumDotDiameterShrink * 100)
            )

            tuningSlider(
                title: "Finder shrink",
                value: $maximumFinderPatternDiameterShrink,
                range: 0 ... 0.5,
                valueText: String(format: "-%.0f%%", maximumFinderPatternDiameterShrink * 100)
            )

            Stepper(
                "Active ripples: \(maximumActiveRippleCount)",
                value: $maximumActiveRippleCount,
                in: 1 ... 100
            )

            Toggle("Center cutout", isOn: $centerCutoutEnabled)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tuningSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText)
                    .foregroundColor(.secondary)
            }
            .font(.caption)

            Slider(value: value, in: range)
        }
    }
}

#Preview("QR Ripple Tuning") {
    QRCodeRippleTuningPreview()
}
