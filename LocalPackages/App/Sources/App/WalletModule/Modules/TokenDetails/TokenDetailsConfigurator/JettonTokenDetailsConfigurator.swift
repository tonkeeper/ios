import BigInt
import Foundation
import KeeperCore
import TKFeatureFlags
import TKLocalize
import TKUIKit

struct JettonTokenDetailsConfigurator: TokenDetailsConfigurator {
    var didUpdate: (() -> Void)?

    private let wallet: Wallet
    private let jettonItem: JettonItem
    private let mapper: TokenDetailsMapper
    private let configuration: Configuration
    private let onShowUnverifiedTokenInfo: (() -> Void)?

    init(
        wallet: Wallet,
        jettonItem: JettonItem,
        mapper: TokenDetailsMapper,
        configuration: Configuration,
        onShowUnverifiedTokenInfo: (() -> Void)? = nil
    ) {
        self.wallet = wallet
        self.jettonItem = jettonItem
        self.mapper = mapper
        self.configuration = configuration
        self.onShowUnverifiedTokenInfo = onShowUnverifiedTokenInfo
    }

    func getTokenModel(balance: ProcessedBalance?, isSecureMode: Bool) -> TokenDetailsModel {
        let jettonBalance = balance?.getBalanceForJetton(jettonItem.jettonInfo)
        let jettonAmount = jettonBalance?.amount ?? 0
        let currency = balance?.currency ?? .defaultCurrency

        var buttons = [
            TokenDetailsModel.Button(
                iconButton: .send(.ton(.jetton(jettonItem))),
                isEnable: wallet.isSendAvailable && jettonItem.jettonInfo.isTransferable && jettonAmount > 0
            ),
            TokenDetailsModel.Button(
                iconButton: .receive(.ton(.jetton(jettonItem))),
                isEnable: true
            ),
        ]

        if !configuration.flag(\.isSwapDisable, network: wallet.network) {
            buttons.append(
                TokenDetailsModel.Button(
                    iconButton: .swap(.ton(.jetton(jettonItem))),
                    isEnable: wallet.isSwapEnable
                )
            )
        }

        let tokenAmount: String
        var convertedAmount: String?
        if isSecureMode {
            tokenAmount = .secureModeValueShort
            convertedAmount = .secureModeValueShort
        } else {
            (tokenAmount, convertedAmount) = mapper.mapJettonBalance(jettonBalance: jettonBalance, currency: currency)
        }

        var caption: TokenDetailsModel.Caption?
        if jettonItem.jettonInfo.isUnverified {
            caption = TokenDetailsModel.Caption(
                text: TKLocales.Token.unverified.withTextStyle(.body2, color: .Accent.orange),
                icon: TKPlainButton.Model.Icon(
                    image: .TKUIKit.Icons.Size12.informationCircle,
                    tintColor: .Accent.orange,
                    padding: .init(top: 4, left: 4, bottom: 4, right: 0)
                ),
                action: onShowUnverifiedTokenInfo
            )
        } else if jettonItem.jettonInfo.isTonUSDT && wallet.isTronTurnOn {
            caption = TokenDetailsModel.Caption(
                text: "TON".withTextStyle(.body2, color: .Text.secondary, alignment: .center)
            )
        }

        return TokenDetailsModel(
            title: jettonItem.jettonInfo.name,
            caption: caption,
            image: .urlImage(jettonItem.jettonInfo.imageURL),
            network: wallet.isTronTurnOn && jettonItem.jettonInfo.isTonUSDT ? .ton : .none,
            tokenAmount: tokenAmount,
            convertedAmount: convertedAmount,
            buttons: buttons,
            bannerItems: []
        )
    }

    func getDetailsURL() -> URL? {
        guard let string = try? "\(String.tonviewer)/\(wallet.friendlyAddress.toString())/jetton/\(jettonItem.jettonInfo.address.toString())",
              let url = URL(string: string) else { return nil }
        return url
    }
}
