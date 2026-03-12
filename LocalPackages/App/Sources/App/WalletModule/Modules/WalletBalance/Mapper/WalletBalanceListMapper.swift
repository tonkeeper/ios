import BigInt
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

struct WalletBalanceListMapper {
    private let dateComponentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    private let stakingMapper: WalletBalanceListStakingMapper
    private let amountFormatter: AmountFormatter
    private let balanceItemMapper: BalanceItemMapper
    private let rateConverter: RateConverter

    init(
        stakingMapper: WalletBalanceListStakingMapper,
        amountFormatter: AmountFormatter,
        balanceItemMapper: BalanceItemMapper,
        rateConverter: RateConverter
    ) {
        self.stakingMapper = stakingMapper
        self.amountFormatter = amountFormatter
        self.rateConverter = rateConverter
        self.balanceItemMapper = balanceItemMapper
    }

    func mapTonItem(
        _ item: ProcessedBalanceTonItem,
        isSecure: Bool,
        isPinned: Bool
    ) -> WalletBalanceListCell.Configuration {
        return WalletBalanceListCell.Configuration(
            walletBalanceListCellContentViewConfiguration: WalletBalanceListCellContentView.Configuration(
                listItemContentViewConfiguration: balanceItemMapper.mapTonItem(item, isSecure: isSecure, isPinned: isPinned),
                commentViewConfiguration: nil
            )
        )
    }

    func mapJettonItem(
        _ item: ProcessedBalanceJettonItem,
        isSecure: Bool,
        isPinned: Bool,
        isNetworkBadgeVisible: Bool
    ) -> WalletBalanceListCell.Configuration {
        return WalletBalanceListCell.Configuration(
            walletBalanceListCellContentViewConfiguration: WalletBalanceListCellContentView.Configuration(
                listItemContentViewConfiguration: balanceItemMapper.mapJettonItem(
                    item,
                    isSecure: isSecure,
                    isPinned: isPinned,
                    isNetworkBadgeVisible: isNetworkBadgeVisible
                ),
                commentViewConfiguration: nil
            )
        )
    }

    func mapStakingItem(
        _ item: ProcessedBalanceStakingItem,
        isSecure: Bool,
        isPinned: Bool,
        isStakingEnable: Bool,
        stakingCollectHandler: (() -> Void)?
    ) -> WalletBalanceListCell.Configuration {
        return stakingMapper.mapStakingItem(
            item,
            isSecure: isSecure,
            isPinned: isPinned,
            isStakingEnable: isStakingEnable,
            stakingCollectHandler: stakingCollectHandler
        )
    }

    func mapTronUSDTItem(
        _ item: ProcessedBalanceTronUSDTItem,
        isSecure: Bool,
        isPinned: Bool
    ) -> WalletBalanceListCell.Configuration {
        return WalletBalanceListCell.Configuration(
            walletBalanceListCellContentViewConfiguration: WalletBalanceListCellContentView.Configuration(
                listItemContentViewConfiguration: balanceItemMapper.mapTronUSDTItem(item: item, isSecure: isSecure, isPinned: isPinned),
                commentViewConfiguration: nil
            )
        )
    }

    func mapEthenaItem(
        _ item: ProcessedBalanceEthenaItem,
        isSecure: Bool,
        isPinned: Bool
    ) -> WalletBalanceListCell.Configuration {
        return WalletBalanceListCell.Configuration(
            walletBalanceListCellContentViewConfiguration: WalletBalanceListCellContentView.Configuration(
                listItemContentViewConfiguration: balanceItemMapper.mapEthenaItem(item: item, isSecure: isSecure, isPinned: isPinned),
                commentViewConfiguration: nil
            )
        )
    }

    func createNotificationsConfiguration() -> WalletBalanceListCell.Configuration {
        createSetupItem(
            text: TKLocales.WalletBalanceList.transactionNotifications,
            icon: .TKUIKit.Icons.Size28.bell,
            iconColor: .Accent.green,
            backgroundColor: .Accent.green.withAlphaComponent(0.12)
        )
    }

    func createBiometryConfiguration() -> WalletBalanceListCell.Configuration {
        let title: String
        let icon: UIImage

        let biometryProvider = BiometryProvider()
        let state = biometryProvider.getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics)
        switch state {
        case let .success(success):
            switch success {
            case .faceID:
                title = TKLocales.FinishSetup.setupBiometry(String.faceID)
                icon = .TKUIKit.Icons.Size28.faceId
            case .touchID:
                title = TKLocales.FinishSetup.setupBiometry(String.touchID)
                icon = .TKUIKit.Icons.Size28.faceId
            case .none:
                title = TKLocales.FinishSetup.biometryUnavailable
                icon = .TKUIKit.Icons.Size28.faceId
            }
        case .failure:
            title = TKLocales.FinishSetup.biometryUnavailable
            icon = .TKUIKit.Icons.Size28.faceId
        }

        return createSetupItem(
            text: title,
            icon: icon,
            iconColor: .Accent.green,
            backgroundColor: .Accent.green.withAlphaComponent(0.12)
        )
    }

    func createBackupConfiguration() -> WalletBalanceListCell.Configuration {
        createSetupItem(
            text: TKLocales.FinishSetup.Backup.title,
            icon: .TKUIKit.Icons.Size28.key,
            captionViewsConfigurations: [
                TKListItemTextView.Configuration(
                    text: TKLocales.FinishSetup.Backup.description,
                    color: .Text.secondary,
                    textStyle: .body2,
                    numberOfLines: 2
                ),
            ],
            iconColor: .Accent.orange,
            backgroundColor: .Accent.orange.withAlphaComponent(0.12)
        )
    }

    private func createSetupItem(
        text: String,
        icon: UIImage,
        captionViewsConfigurations: [TKListItemTextView.Configuration] = [],
        iconColor: UIColor,
        backgroundColor: UIColor,
        corners: TKImageView.Corners = .circle,
        cornerRadius: CGFloat = .iconCornerRadius
    ) -> WalletBalanceListCell.Configuration {
        WalletBalanceListCell.Configuration(
            walletBalanceListCellContentViewConfiguration: WalletBalanceListCellContentView.Configuration(
                listItemContentViewConfiguration: TKListItemContentView.Configuration(
                    iconViewConfiguration: TKListItemIconView.Configuration(
                        content: .image(
                            TKImageView.Model(
                                image: .image(icon),
                                tintColor: iconColor,
                                size: .auto,
                                corners: corners
                            )
                        ),
                        alignment: .top,
                        cornerRadius: cornerRadius,
                        backgroundColor: backgroundColor,
                        size: .iconSize
                    ),
                    textContentViewConfiguration: TKListItemTextContentView.Configuration(
                        titleViewConfiguration: TKListItemTitleView.Configuration(
                            title: text.withTextStyle(.body2, color: .Text.primary),
                            numberOfLines: 0
                        ),
                        captionViewsConfigurations: captionViewsConfigurations
                    )
                )
            )
        )
    }
}

private extension CGSize {
    static let iconSize = CGSize(width: 44, height: 44)
}

private extension CGFloat {
    static let iconCornerRadius: CGFloat = 22
}

extension String {
    static let secureModeValueShort = "* * *"
    static let secureModeValueLong = "* * * *"
    static let faceID = TKLocales.SettingsListSecurityConfigurator.faceId
    static let touchID = TKLocales.SettingsListSecurityConfigurator.touchId
}
