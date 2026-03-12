import BigInt
import Foundation
import KeeperCore
import TKFeatureFlags
import TKLocalize

struct TonTokenDetailsConfigurator: TokenDetailsConfigurator {
    var didUpdate: (() -> Void)?

    private let wallet: Wallet
    private let mapper: TokenDetailsMapper
    private let configuration: Configuration

    init(
        wallet: Wallet,
        mapper: TokenDetailsMapper,
        configuration: Configuration
    ) {
        self.wallet = wallet
        self.mapper = mapper
        self.configuration = configuration
    }

    func getTokenModel(balance: ProcessedBalance?, isSecureMode: Bool) -> TokenDetailsModel {
        let tonAmount = balance?.tonItem.amount ?? 0

        var buttons = [
            TokenDetailsModel.Button(
                iconButton: .send(.ton(.ton)),
                isEnable: wallet.isSendAvailable && tonAmount > 0
            ),
            TokenDetailsModel.Button(
                iconButton: .receive(.ton(.ton)),
                isEnable: true
            ),
        ]

        if !configuration.flag(\.isSwapDisable, network: wallet.network) {
            buttons.append(TokenDetailsModel.Button(
                iconButton: .swap(.ton(.ton)),
                isEnable: wallet.isSwapEnable
            ))
        }

        let tokenAmount: String
        let convertedAmount: String?
        if isSecureMode {
            tokenAmount = .secureModeValueShort
            convertedAmount = .secureModeValueShort
        } else {
            let amount = mapper.mapTonBalance(tonBalance: balance?.tonItem, currency: balance?.currency)
            tokenAmount = amount.tokenAmount
            convertedAmount = amount.convertedAmount
        }

        return TokenDetailsModel(
            title: TonInfo.name,
            caption: nil,
            image: .image(.App.Currency.Vector.ton),
            network: .none,
            tokenAmount: tokenAmount,
            convertedAmount: convertedAmount,
            buttons: buttons,
            bannerItems: []
        )
    }

    func getDetailsURL() -> URL? {
        guard let string = try? "\(String.tonviewer)/\(wallet.friendlyAddress.toString())",
              let url = URL(string: string) else { return nil }
        return url
    }
}
