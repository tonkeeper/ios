import TKUIKit

struct MultichainSwapConfirmationDisplay {
    let sendLine: String
    let receiveLine: String
    let sendTokenAvatarSource: AssetAvatarViewImageSource
    let receiveTokenAvatarSource: AssetAvatarViewImageSource
    let rateLine: String
    let slippageLine: String
    let minimumReceivedLine: String
    let priceImpactTitle: String
    let priceImpactValue: String?
    let networkFeeTitle: String
    let networkFeeValue: String
    let networkFeeMethod: String
    let canPickFeeMethod: Bool
    let networkFeeSubtitle: String
}
