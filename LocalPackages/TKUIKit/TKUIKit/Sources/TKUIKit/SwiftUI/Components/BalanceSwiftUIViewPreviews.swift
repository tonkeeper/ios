import SwiftUI

struct BalanceSwiftUIViewPreviews: View {
    @State private var selectedBalanceCase: BalancePreviewCase = .regularRightSymbol
    @State private var animatedBalanceIndex = 0
    @State private var hasLoadingStatus = false
    @State private var hasStatus = true
    @State private var hasAddress = true
    @State private var shimmering = false
    @State private var pending = false
    @State private var longAddress = false

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sectionTitle("Selected balance")
                selectedBalanceView

                controlsView

                sectionTitle("Numeric transition")
                animatedBalanceView

                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        animatedBalanceIndex = (animatedBalanceIndex + 1) % Self.animatedCases.count
                    }
                } label: {
                    toggleTitle("Update animated balance")
                }

                sectionTitle("All balance states")
                balanceCasesView
            }
            .padding(.all, 16)
        }
        .tkImmediateButtonPresses()
        .debugPreview(background: .page)
    }
}

private extension BalanceSwiftUIViewPreviews {
    static let animatedCases: [BalancePreviewCase] = [
        .regularRightSymbol,
        .regularRightSymbolUpdated,
        .millionReduced,
        .compactMillion,
        .compactBillion,
    ]

    var selectedBalanceView: some View {
        BalanceSwiftUIView(config: shimmering ? .shimmer : .content(content(for: selectedBalanceCase)))
            .animation(.default, value: content(for: selectedBalanceCase))
            .animation(.default, value: shimmering)
    }

    @ViewBuilder
    var animatedBalanceView: some View {
        let content = content(for: Self.animatedCases[animatedBalanceIndex])
        if #available(iOS 17.0, *) {
            BalanceSwiftUIView(config: .content(content))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.35), value: content)
        } else {
            BalanceSwiftUIView(config: .content(content))
                .animation(.easeInOut(duration: 0.35), value: content)
        }
    }

    var controlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(selection: $selectedBalanceCase) {
                ForEach(BalancePreviewCase.selectableCases) { balanceCase in
                    Text(balanceCase.title).tag(balanceCase)
                }
            } label: {
                toggleTitle("Balance")
            }

            Toggle(isOn: $hasLoadingStatus) {
                toggleTitle("Loading status")
            }

            Toggle(isOn: $hasStatus) {
                toggleTitle("Status")
            }

            Toggle(isOn: $hasAddress) {
                toggleTitle("Address")
            }

            Toggle(isOn: $shimmering) {
                toggleTitle("Shimmer")
            }

            Toggle(isOn: $pending) {
                toggleTitle("Pending balance")
            }

            Toggle(isOn: $longAddress) {
                toggleTitle("Long address")
            }
            .disabled(!hasAddress)
            .opacity(hasAddress ? 1 : 0.48)
        }
    }

    var balanceCasesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(BalancePreviewCase.galleryCases) { balanceCase in
                VStack(alignment: .leading, spacing: 4) {
                    toggleTitle(balanceCase.title)
                    BalanceSwiftUIView(config: .content(content(for: balanceCase)))
                }
            }
        }
    }

    func content(for balanceCase: BalancePreviewCase) -> BalanceViewContent {
        BalanceViewContent(
            balance: balanceCase.balance.settingFreshness(pending ? .pending : .actual),
            address: statusConfig,
            battery: batteryConfig(for: balanceCase),
            backupButton: backupButton(for: balanceCase)
        )
    }

    func batteryConfig(for balanceCase: BalancePreviewCase) -> BatterySwiftUIViewConfig? {
        guard balanceCase != .secure else {
            return nil
        }

        return BatterySwiftUIViewConfig(
            size: .size34,
            state: .fill(0.5)
        )
    }

    func backupButton(for balanceCase: BalancePreviewCase) -> BalanceViewContent.BackupButton? {
        switch balanceCase {
        case .backupWarning:
            return BalanceViewContent.BackupButton(color: .accentOrange)
        default:
            return nil
        }
    }

    var statusConfig: BalanceHeaderBalanceStatusViewConfig? {
        if hasLoadingStatus {
            return BalanceHeaderBalanceStatusViewConfig(
                state: .connection(BalanceHeaderBalanceStatusViewConfig.ConnectionStatus(
                    title: "Updating",
                    titleColor: .textSecondary,
                    isLoading: true
                ))
            )
        }

        if hasStatus {
            return BalanceHeaderBalanceStatusViewConfig(
                state: .updated("Updated at 12:48")
            )
        }

        if hasAddress {
            return BalanceHeaderBalanceStatusViewConfig(
                state: .address(
                    "Your address: \(address)",
                    tags: [
                        .tag(text: "v4r2"),
                        .accentTag(text: "w5", accent: .accentBlue),
                    ]
                )
            )
        }

        return nil
    }

    var address: String {
        longAddress
            ? "UQDxzbcLzjNqQp5sGzj4wEGMMeEuP6eqxEGEcPlBrsf92"
            : "UQDx...sf92"
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .textStyle(.label1)
            .foregroundStyle(.textPrimary)
    }

    func toggleTitle(_ title: String) -> some View {
        Text(title)
            .textStyle(.body2)
            .foregroundStyle(.textPrimary)
    }
}

private enum BalancePreviewCase: String, CaseIterable, Identifiable {
    case regularRightSymbol
    case regularRightSymbolUpdated
    case regularLeftSymbol
    case tokenWithLongFraction
    case millionReduced
    case compactMillion
    case compactBillion
    case backupWarning
    case secure

    var id: String {
        rawValue
    }

    static var selectableCases: [Self] {
        [
            .regularRightSymbol,
            .regularLeftSymbol,
            .tokenWithLongFraction,
            .millionReduced,
            .compactMillion,
            .compactBillion,
            .backupWarning,
            .secure,
        ]
    }

    static var galleryCases: [Self] {
        selectableCases
    }

    var title: String {
        switch self {
        case .regularRightSymbol:
            return "Regular, symbol right"
        case .regularRightSymbolUpdated:
            return "Regular updated"
        case .regularLeftSymbol:
            return "Regular, symbol left"
        case .tokenWithLongFraction:
            return "Token fraction"
        case .millionReduced:
            return "1M...10M reduced"
        case .compactMillion:
            return "Compact M with tooltip"
        case .compactBillion:
            return "Compact B with tooltip"
        case .backupWarning:
            return "Backup warning"
        case .secure:
            return "Secure"
        }
    }

    @MainActor
    var balance: BalanceViewContent.Balance {
        switch self {
        case .regularRightSymbol:
            return amount(
                trailingText: "\u{20BD}",
                textParts: [
                    .init(text: "7 362", role: .primary),
                    .init(text: ".45", role: .fraction),
                ],
                accessibilityText: "7 362.45 \u{20BD}"
            )
        case .regularRightSymbolUpdated:
            return amount(
                trailingText: "\u{20BD}",
                textParts: [
                    .init(text: "7 481", role: .primary),
                    .init(text: ".09", role: .fraction),
                ],
                accessibilityText: "7 481.09 \u{20BD}"
            )
        case .regularLeftSymbol:
            return amount(
                leadingText: "$",
                textParts: [
                    .init(text: "7 362", role: .primary),
                    .init(text: ".45", role: .fraction),
                ],
                accessibilityText: "$ 7 362.45"
            )
        case .tokenWithLongFraction:
            return amount(
                trailingText: "TON",
                textParts: [
                    .init(text: "0", role: .primary),
                    .init(text: ".000045", role: .fraction),
                ],
                accessibilityText: "0.000045 TON"
            )
        case .millionReduced:
            return amount(
                trailingText: "\u{20BD}",
                textParts: [
                    .init(text: "8 456 362", role: .primary),
                    .init(text: ".45", role: .fraction),
                ],
                textSize: .reduced,
                accessibilityText: "8 456 362.45 \u{20BD}"
            )
        case .compactMillion:
            return amount(
                trailingText: "\u{20BD}",
                textParts: [
                    .init(text: "26.6M", role: .primary),
                ],
                tooltipText: "26 666 666.45 \u{20BD}",
                accessibilityText: "26 666 666.45 \u{20BD}"
            )
        case .compactBillion:
            return amount(
                trailingText: "\u{20BD}",
                textParts: [
                    .init(text: "1.2B", role: .primary),
                ],
                tooltipText: "1 250 000 000.00 \u{20BD}",
                accessibilityText: "1 250 000 000.00 \u{20BD}"
            )
        case .backupWarning:
            return amount(
                trailingText: "\u{20BD}",
                textParts: [
                    .init(text: "845", role: .primary),
                    .init(text: ".12", role: .fraction),
                ],
                accessibilityText: "845.12 \u{20BD}",
                color: .accentOrange
            )
        case .secure:
            return .secure()
        }
    }

    private func amount(
        leadingText: String? = nil,
        trailingText: String? = nil,
        textParts: [BalanceViewContent.Balance.Amount.TextPart],
        textSize: BalanceViewContent.Balance.Amount.TextSize = .regular,
        tooltipText: String? = nil,
        accessibilityText: String,
        color: TKColor = .textPrimary
    ) -> BalanceViewContent.Balance {
        BalanceViewContent.Balance(
            amount: BalanceViewContent.Balance.Amount(
                leadingText: leadingText,
                trailingText: trailingText,
                textParts: textParts,
                textSize: textSize,
                tooltipText: tooltipText,
                accessibilityText: accessibilityText,
                color: color
            )
        )
    }
}

#Preview {
    BalanceSwiftUIViewPreviews()
        .tkThemed()
}
