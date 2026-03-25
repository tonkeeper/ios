import Foundation

enum SignDataError: Error {
    case wrongPayloadType
    case invalidDataEncoding
    case signatureFailure
    case addressFailure
}

public struct SignedDataResult: Encodable {
    public let signature: String
    public let timestamp: UInt64
    public let address: String
    public let domain: String
    public let payload: TonConnectSignDataPayload
}

public protocol SignDataSigner {
    func sign(
        wallet: Wallet,
        mnemonicsRepository: MnemonicsRepository,
        dappUrl: String,
        passcode: String
    ) async throws -> SignedDataResult
}
