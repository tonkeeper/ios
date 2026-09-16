import Foundation

struct WalletConnectPersonalSignParser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain _: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let method: WalletConnectMethod = .personalSign
        let params = try utilities.parseStringList(paramsJSON: paramsJSON, method: method)
        guard params.count >= 2 else {
            throw .invalidParams(method: method, reason: "personal_sign requires data and address")
        }

        return .signMessage(
            WalletConnectSignMessage(
                address: params[1],
                message: params[0],
                kind: .personal
            )
        )
    }
}
