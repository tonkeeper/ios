import TKUIKit

struct TradeShelfAssetViewData: Identifiable {
    var id: String
    var symbol: String
    var iconImageSource: AssetAvatarViewImageSource
    var changeText: String?
    var changeColor: TKColor
    var isChangeLoading: Bool
    var preview: TradeAssetDetailsViewModel.PreviewContext
}
