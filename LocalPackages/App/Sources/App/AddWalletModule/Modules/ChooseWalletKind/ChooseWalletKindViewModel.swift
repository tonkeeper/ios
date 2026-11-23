import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit

@MainActor
protocol ChooseWalletKindModuleOutput: AnyObject {
    var didSelectKind: ((ImportWalletKind) -> Void)? { get set }
}

@MainActor
protocol ChooseWalletKindModuleInput: AnyObject {
    func resetContinueImport()
    func clearContinueLoader()
}

struct ChooseWalletKindRow: Identifiable {
    let id: ImportWalletKind
    let title: String
    let subtitle: String
    let icon: ChooseWalletKindIcon
}

enum ChooseWalletKindIcon {
    case ton
    case multichain
    case telegram
}

struct ChooseWalletKindOption {
    let kind: ImportWalletKind
    let preview: ImportWalletKindPreview
}

@MainActor
final class ChooseWalletKindViewModel: ObservableObject, ChooseWalletKindModuleOutput, ChooseWalletKindModuleInput {
    @Published private(set) var rows: [ChooseWalletKindRow] = []
    @Published private(set) var selectedKind: ImportWalletKind
    @Published private(set) var isContinueInProgress = false
    @Published private(set) var showsContinueLoader = false

    var didSelectKind: ((ImportWalletKind) -> Void)?

    init(
        options: [ChooseWalletKindOption],
        amountFormatter: AmountFormatter,
        currency: Currency
    ) {
        self.selectedKind = Self.defaultKind(options: options)
        self.rows = options.map { option in
            Self.makeRow(
                kind: option.kind,
                preview: option.preview,
                amountFormatter: amountFormatter,
                currency: currency
            )
        }
    }

    var description: String {
        rows.count > 2
            ? TKLocales.ChooseWalletKind.descriptionThree
            : TKLocales.ChooseWalletKind.description
    }

    func selectKind(_ kind: ImportWalletKind) {
        guard !isContinueInProgress, selectedKind != kind else { return }
        selectedKind = kind
    }

    func continueImport() {
        guard !isContinueInProgress else { return }
        isContinueInProgress = true
        showsContinueLoader = true
        didSelectKind?(selectedKind)
    }

    func resetContinueImport() {
        isContinueInProgress = false
        showsContinueLoader = false
    }

    func clearContinueLoader() {
        showsContinueLoader = false
    }

    func isSelected(_ row: ChooseWalletKindRow) -> Bool {
        row.id == selectedKind
    }
}

private extension ChooseWalletKindViewModel {
    static func defaultKind(options: [ChooseWalletKindOption]) -> ImportWalletKind {
        if options.contains(where: { $0.kind == .telegram }) {
            return .telegram
        }
        let preview: (ImportWalletKind) -> ImportWalletKindPreview = { kind in
            options.first { $0.kind == kind }?.preview ?? .empty
        }
        if preview(.multichain).fiatTotal > preview(.ton).fiatTotal {
            return .multichain
        }
        return options.contains { $0.kind == .ton } ? .ton : options.first?.kind ?? .ton
    }

    static func makeRow(
        kind: ImportWalletKind,
        preview: ImportWalletKindPreview,
        amountFormatter: AmountFormatter,
        currency: Currency
    ) -> ChooseWalletKindRow {
        let title: String
        let icon: ChooseWalletKindIcon
        switch kind {
        case .ton:
            title = TKLocales.ChooseWalletKind.tonWallet
            icon = .ton
        case .multichain:
            title = TKLocales.ChooseWalletKind.multichainWallet
            icon = .multichain
        case .telegram:
            title = TKLocales.ChooseWalletKind.telegramWallet
            icon = .telegram
        }

        let subtitle: String
        if preview.hasActivity {
            let balanceText = amountFormatter.format(
                decimal: preview.fiatTotal,
                accessory: .fiat(currency),
                style: .fiatBalance
            )
            if preview.nftsCount > 0 {
                subtitle = "\(balanceText) · \(TKLocales.ChooseWalletKind.nftsCount(preview.nftsCount))"
            } else {
                subtitle = balanceText
            }
        } else {
            subtitle = TKLocales.ChooseWalletKind.noActivityYet
        }

        return ChooseWalletKindRow(
            id: kind,
            title: title,
            subtitle: subtitle,
            icon: icon
        )
    }
}
