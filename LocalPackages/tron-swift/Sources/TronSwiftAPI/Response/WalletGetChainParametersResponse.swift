import Foundation

struct WalletGetChainParametersResponse: Decodable {
    var chainParameter: [ChainParameter]

    struct ChainParameter: Decodable {
        var key: String
        var value: Int64?
    }
}
