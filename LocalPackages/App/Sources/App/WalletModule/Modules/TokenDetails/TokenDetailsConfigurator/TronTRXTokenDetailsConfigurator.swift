import Foundation
import KeeperCore
import TKUIKit
import TronSwift

struct TronTRXTokenDetailsConfigurator: TokenDetailsConfigurator {
    var didUpdate: (() -> Void)?

    private let wallet: Wallet
    private let mapper: TokenDetailsMapper

    init(
        wallet: Wallet,
        mapper: TokenDetailsMapper
    ) {
        self.wallet = wallet
        self.mapper = mapper
    }

    func getTokenModel(balance: ProcessedBalance?, isSecureMode: Bool) -> TokenDetailsModel {
        let trxItem = balance?.tronTRXItem

        let tokenAmount: String
        let convertedAmount: String?
        if isSecureMode {
            tokenAmount = .secureModeValueShort
            convertedAmount = .secureModeValueShort
        } else {
            let amount = mapper.mapBalance(
                amount: trxItem?.amount ?? 0,
                converted: trxItem?.converted ?? 0,
                fractionDigits: TronSwift.TRX.fractionDigits,
                symbol: TronSwift.TRX.symbol,
                currency: balance?.currency ?? .USD
            )
            tokenAmount = amount.tokenAmount
            convertedAmount = amount.convertedAmount
        }

        return TokenDetailsModel(
            title: TronSwift.TRX.name,
            caption: nil,
            image: .image(.TKUIKit.Icons.Size44.trxChain),
            network: .none,
            tokenAmount: tokenAmount,
            convertedAmount: convertedAmount,
            buttons: [
                TokenDetailsModel.Button(
                    iconButton: .send(.tron(.trx)),
                    isEnable: wallet.isSendAvailable && (trxItem?.amount ?? 0) > 0
                ),
                TokenDetailsModel.Button(
                    iconButton: .receive(.tron(.trx)),
                    isEnable: true
                ),
            ],
            bannerItems: []
        )
    }

    func getDetailsURL() -> URL? {
        guard let address = wallet.tron?.address.base58 else { return nil }
        return URL(string: "\(String.tronscan)/\(address)")
    }
}
