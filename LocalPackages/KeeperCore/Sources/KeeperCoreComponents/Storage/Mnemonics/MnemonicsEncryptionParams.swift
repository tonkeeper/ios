import Foundation

struct MnemonicsEncryptionParams: Equatable {
    static let production = MnemonicsEncryptionParams(N: 16384, r: 8, p: 1)
    static let passwordKeyLength = 32

    let N: Int
    let r: Int
    let p: Int
}
