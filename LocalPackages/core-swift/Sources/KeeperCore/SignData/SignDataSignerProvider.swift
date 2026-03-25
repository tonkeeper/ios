import Foundation

public enum SignDataSignerProvider {
    public static func getSigner(signDataPayload: TonConnect.SignDataRequest) -> SignDataSigner {
        switch signDataPayload.params {
        case .text, .binary:
            return TextOrBinSignDataSigner(signDataPayload: signDataPayload)
        case .cell:
            return CellSignDataSigner(signDataPayload)
        }
    }
}
