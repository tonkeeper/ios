@preconcurrency import BigInt
import Foundation
import TKLogging

struct WalletConnectEthSignTypedDataV4Parser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let params = try utilities.parseStringList(paramsJSON: paramsJSON, method: method)
        guard params.count >= 2 else {
            throw .invalidParams(method: method, reason: "eth_signTypedData_v4 requires address and typed data")
        }

        if let domainChainId = try parseTypedDataDomainChainId(params[1]),
           let expectedChainId = chain.eip155ChainId,
           domainChainId != BigUInt(expectedChainId)
        {
            throw .chainMismatch(expected: chain, actual: domainChainId.description)
        }

        return .signMessage(
            WalletConnectSignMessage(
                address: params[0],
                message: params[1],
                kind: .typedDataV4
            )
        )
    }
}

private extension WalletConnectEthSignTypedDataV4Parser {
    var method: WalletConnectMethod {
        .ethSignTypedDataV4
    }

    func parseTypedDataDomainChainId(
        _ typedData: String
    ) throws(WalletConnectRequestParsingError) -> BigUInt? {
        let data = try utilities.data(
            from: typedData,
            method: method,
            utf8FailureReason: "typed data is not utf8"
        )

        struct TypedData: Decodable {
            struct Domain: Decodable {
                var chainId: WalletConnectUInt256Value?

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.chainId = try? container.decodeIfPresent(WalletConnectUInt256Value.self, forKey: .chainId)
                }

                private enum CodingKeys: CodingKey {
                    case chainId
                }
            }

            var domain: Domain?

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                do {
                    self.domain = try container.decodeIfPresent(Domain.self, forKey: .domain)
                } catch {
                    self.domain = nil
                }
            }

            private enum CodingKeys: CodingKey {
                case domain
            }
        }

        let typedData: TypedData
        do {
            typedData = try JSONDecoder().decode(TypedData.self, from: data)
        } catch {
            Log.w(
                "WalletConnect: failed to decode typed data domain",
                error: error,
                extraInfo: ["method": method.rawValue]
            )
            return nil
        }

        guard let chainId = typedData.domain?.chainId?.value else {
            return nil
        }
        return chainId
    }
}
