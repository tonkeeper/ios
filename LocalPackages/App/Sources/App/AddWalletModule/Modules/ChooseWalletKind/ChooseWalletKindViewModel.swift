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
}

@MainActor
final class ChooseWalletKindViewModel: ObservableObject, ChooseWalletKindModuleOutput, ChooseWalletKindModuleInput {
    @Published private(set) var rows: [ChooseWalletKindRow] = []
    @Published private(set) var selectedKind: ImportWalletKind
    @Published private(set) var isContinueInProgress = false
    @Published private(set) var showsContinueLoader = false

    var didSelectKind: ((ImportWalletKind) -> Void)?

    private let tonPreview: ImportWalletKindPreview
    private let multichainPreview: ImportWalletKindPreview

    init(
        tonPreview: ImportWalletKindPreview,
        multichainPreview: ImportWalletKindPreview,
        amountFormatter: AmountFormatter,
        currency: Currency
    ) {
        self.tonPreview = tonPreview
        self.multichainPreview = multichainPreview
        self.selectedKind = Self.defaultKind(ton: tonPreview, multichain: multichainPreview)
        self.rows = [
            Self.makeRow(
                kind: .ton,
                preview: tonPreview,
                amountFormatter: amountFormatter,
                currency: currency
            ),
            Self.makeRow(
                kind: .multichain,
                preview: multichainPreview,
                amountFormatter: amountFormatter,
                currency: currency
            ),
        ]
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
    static func defaultKind(
        ton: ImportWalletKindPreview,
        multichain: ImportWalletKindPreview
    ) -> ImportWalletKind {
        if multichain.fiatTotal > ton.fiatTotal {
            return .multichain
        }
        return .ton
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
