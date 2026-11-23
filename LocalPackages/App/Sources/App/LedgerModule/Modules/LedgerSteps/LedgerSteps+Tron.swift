import Foundation
import LedgerKit
import TKLocalize

extension LedgerSteps where Value == Data {
    /// Signs a Tron transaction's `raw_data` in the Tron app.
    static func tronTransaction(_ rawData: Data, account: Int) -> LedgerSteps<Data> {
        LedgerSteps(
            stages: [.init(app: .tron, prompt: TKLocales.LedgerConfirm.Steps.Confirm.description)],
            run: { session in
                try await session.run(on: .tron) { link in
                    do {
                        return try await link.signTronTransaction(rawData, path: TronApp.path(account: account))
                    } catch let error as LedgerStatusError {
                        guard let setting = TronApp.Setting(error) else {
                            throw error
                        }
                        throw LedgerStepsFailure(message: TKLocales.LedgerSteps.appSetting(setting.title, LedgerApp.tron.name))
                    }
                }
            }
        )
    }
}

private extension TronApp.Setting {
    /// As the Tron app's settings name it.
    var title: String {
        switch self {
        case .transactionsData:
            "Transactions data"
        case .customContracts:
            "Custom contracts"
        case .signByHash:
            "Blind signing"
        }
    }
}
