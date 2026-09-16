import KeeperCore
import SwiftUI
import TKUIKit
import UIKit

enum BalanceSwiftUIMapper {
    static func balanceViewConfig(
        portfolioTotal: (amount: Decimal, currency: Currency)?,
        wallet: Wallet,
        state: WalletTotalBalanceModel.State,
        freshness: BalanceFreshness,
        headerMapper: WalletBalanceHeaderMapper,
        configuration: Configuration
    ) -> BalanceViewConfig {
        let tonAmount = state.totalBalanceState?.totalBalance?.balance.tonItems.first?.amount ?? 0
        let backupWarningState = BalanceBackupWarningCheck().check(
            wallet: wallet,
            tonAmount: tonAmount
        )

        let balanceColor: TKColor
        let backupButton: BalanceViewContent.BackupButton?
        switch backupWarningState {
        case .error:
            balanceColor = .accentRed
            backupButton = BalanceViewContent.BackupButton(color: .accentRed)
        case .warning:
            balanceColor = .accentOrange
            backupButton = BalanceViewContent.BackupButton(color: .accentOrange)
        case .none:
            balanceColor = .textPrimary
            backupButton = nil
        }

        let balanceContent: BalanceViewContent.Balance = {
            if state.isSecure {
                return .secure(color: balanceColor)
            }
            guard let portfolioTotal else {
                return BalanceViewContent.Balance(text: "-", color: balanceColor)
            }
            return headerMapper.mapFiatBalanceAmount(
                amount: portfolioTotal.amount,
                currency: portfolioTotal.currency,
                color: balanceColor
            )
        }()

        let batteryConfig = batterySwiftUIConfig(
            wallet: wallet,
            batteryBalance: state.totalBalanceState?.totalBalance?.batteryBalance,
            configuration: configuration
        )

        let content = BalanceViewContent(
            balance: balanceContent.settingFreshness(freshness),
            address: addressConfig(wallet: wallet),
            battery: batteryConfig,
            backupButton: backupButton,
            amountScope: wallet.id
        )

        return .content(content)
    }

    private static func addressConfig(wallet: Wallet) -> BalanceHeaderBalanceStatusViewConfig? {
        guard let address = wallet.multichainAddress(for: .ton) else {
            return nil
        }
        return BalanceHeaderBalanceStatusViewConfig(
            state: .address(address.shortReceiveAddress, tags: [], showsChevron: true)
        )
    }

    private static func batterySwiftUIConfig(
        wallet: Wallet,
        batteryBalance: BatteryBalance?,
        configuration: Configuration
    ) -> BatterySwiftUIViewConfig? {
        guard wallet.kind == .regular else {
            return nil
        }

        guard !configuration.flag(\.batteryDisabled, network: wallet.network) else {
            return nil
        }

        switch batteryBalance?.batteryState {
        case let .some(.fill(percents)):
            return BatterySwiftUIViewConfig(size: .size34, state: .fill(percents))
        case .some(.negative):
            return BatterySwiftUIViewConfig(size: .size34, state: .negative)
        case .some(.empty), .none:
            return BatterySwiftUIViewConfig(size: .size34, state: .emptyTinted)
        }
    }
}
