import AppUI
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

@MainActor
public protocol PerpsTradeConfirmViewModeling: ObservableObject {
    var rows: [PerpsTradeConfirmRow] { get }
    var isConfirmationEnabled: Bool { get }
    var isProcessing: Bool { get }
    var titleText: String { get }
    var iconLetter: String { get }
    var iconURL: URL? { get }
    /// The network badge on the icon.
    var iconChainImage: UIImage? { get }
    /// Shown after the title in tertiary: the network the asset lives on.
    var titleSuffixText: String? { get }
    var noticeText: String? { get }
    var isNoticeError: Bool { get }
    var isNoticeWarning: Bool { get }

    func onAppear()
    func onDisappear()
    func back()
    func close()
    func editAutoClose()
    func confirm()
}

public extension PerpsTradeConfirmViewModeling {
    var isProcessing: Bool {
        false
    }

    var iconChainImage: UIImage? {
        nil
    }

    var titleSuffixText: String? {
        nil
    }

    var noticeText: String? {
        nil
    }

    var isNoticeError: Bool {
        false
    }

    var isNoticeWarning: Bool {
        false
    }
}

public struct PerpsTradeConfirmView<ViewModel: PerpsTradeConfirmViewModeling>: View {
    @ObservedObject private var viewModel: ViewModel

    public init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ConfirmActionView(state: state, onBack: viewModel.back, onClose: viewModel.close)
            .onAppear { viewModel.onAppear() }
            .onDisappear { viewModel.onDisappear() }
    }

    private var state: ConfirmActionState {
        ConfirmActionState(
            header: viewModel.iconURL.map { .avatar(.url($0, chainIcon: viewModel.iconChainImage)) }
                ?? .letter(viewModel.iconLetter),
            caption: TKLocales.Perps.Confirm.title,
            title: viewModel.titleText,
            titleSuffix: viewModel.titleSuffixText,
            rows: viewModel.rows.map(row),
            notice: viewModel.noticeText.map { .init(text: $0, isError: viewModel.isNoticeError, isWarning: viewModel.isNoticeWarning) },
            action: ConfirmActionBarState(
                kind: .slider(title: TKLocales.Perps.Confirm.confirm, subtitle: TKLocales.Perps.Confirm.swipe),
                isEnabled: viewModel.isConfirmationEnabled,
                process: viewModel.isProcessing ? .processing : .idle,
                successTitle: TKLocales.Result.success,
                failureTitle: TKLocales.Result.failure,
                accessibilityIdentifier: "perps_confirm_swipe",
                onConfirm: viewModel.confirm
            )
        )
    }

    private func row(_ row: PerpsTradeConfirmRow) -> ConfirmActionRow {
        let value: ConfirmActionRow.Value = if let parts = row.valueParts, !parts.isEmpty {
            .parts(parts.map { .init(text: $0.text, tone: $0.tone.confirmTone) }, subtitle: row.subValue)
        } else {
            .text(row.value, subtitle: row.subValue, tone: row.tone.confirmTone)
        }
        return ConfirmActionRow(
            id: "\(row.id)",
            title: row.title,
            value: value,
            interaction: row.showsChevron ? .tap(viewModel.editAutoClose, showsChevron: true) : .none,
            isEnabled: viewModel.isConfirmationEnabled
        )
    }
}

private extension PerpsTradeConfirmTone {
    var confirmTone: ConfirmActionRow.Tone {
        switch self {
        case .neutral: .primary
        case .positive: .positive
        case .negative: .negative
        case .tertiary: .tertiary
        case .accent: .accent
        }
    }
}
