import SwiftUI

public struct ConfirmSliderPreviews: View {
    @State private var confirmations = 0
    @State private var failsNextOperation = false

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                row("Standard") {
                    slider()
                }
                row("Warning") {
                    slider(appearance: .warning)
                }
                row("Danger") {
                    slider(appearance: .danger)
                }
                row("Disabled") {
                    TKConfirmSlider(isEnabled: false) {}
                }
                Text("Confirmed: \(confirmations)")
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                Toggle(isOn: $failsNextOperation) {
                    Text("Fail the next operation")
                        .textStyle(.body2)
                        .foregroundStyle(.textPrimary)
                }
            }
            .padding(16)
        }
        .tkScrollEdgeBar {
            slider()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(.backgroundPage)
        .navigationBarBackButtonHidden(true)
    }

    private func slider(appearance: TKConfirmSlider.Appearance = .standard) -> some View {
        DemoSlider(appearance: appearance, fails: failsNextOperation) {
            confirmations += 1
        }
    }

    private func row<Slider: View>(_ title: String, @ViewBuilder slider: () -> Slider) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
            slider()
        }
    }
}

private struct DemoSlider: View {
    let appearance: TKConfirmSlider.Appearance
    let fails: Bool
    let onConfirm: () -> Void

    @State private var process: TKActionBarProcess = .idle
    @State private var operation: Task<Void, Error>?

    var body: some View {
        TKConfirmSlider(appearance: appearance, process: process, onConfirm: run)
            .onDisappear {
                operation?.cancel()
                process = .idle
            }
    }

    private func run() {
        let fails = fails
        onConfirm()
        operation?.cancel()
        process = .processing
        operation = Task {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            process = fails ? .failure : .success
            try await Task.sleep(nanoseconds: fails ? 1_300_000_000 : 1_500_000_000)
            process = .idle
        }
    }
}
