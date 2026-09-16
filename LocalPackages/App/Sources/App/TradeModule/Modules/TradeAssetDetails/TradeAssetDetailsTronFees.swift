import Foundation

enum TradeAssetDetailsTronFeesViewData: Equatable {
    struct Banner: Equatable {
        enum Style {
            case trx
            case battery
        }

        let title: String
        let caption: String
        let buttonTitle: String
        let style: Style
    }

    case banner(Banner)
    case transfersAvailable(String)
}

enum TradeAssetDetailsTronFeesTrigger {
    case banner
    case transfersAvailable
    case insufficientSend
}
