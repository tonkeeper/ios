import Foundation

struct WalletConnectTONSignDataParser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain _: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let method: WalletConnectMethod = .tonSignData
        let param = try decodeFirstParam(
            from: paramsJSON,
            method: method
        )

        return try .tonSignData(
            WalletConnectTONSignData(
                address: param.address ?? param.from,
                payload: payload(from: param, method: method),
                rawParamsJSON: paramsJSON
            )
        )
    }
}

private extension WalletConnectTONSignDataParser {
    struct Param: Decodable {
        var type: String
        var text: String?
        var bytes: String?
        var schema: String?
        var cell: String?
        var address: String?
        var from: String?
    }

    func payload(
        from param: Param,
        method: WalletConnectMethod
    ) throws(WalletConnectRequestParsingError) -> WalletConnectTONSignData.Payload {
        switch param.type {
        case "text":
            guard let text = param.text else {
                throw .invalidParams(method: method, reason: "ton_signData text payload is missing text")
            }
            return .text(text)
        case "binary":
            guard let bytes = param.bytes else {
                throw .invalidParams(method: method, reason: "ton_signData binary payload is missing bytes")
            }
            return .binary(bytes)
        case "cell":
            guard let schema = param.schema,
                  let cell = param.cell
            else {
                throw .invalidParams(method: method, reason: "ton_signData cell payload is missing schema or cell")
            }
            return .cell(schema: schema, cell: cell)
        default:
            throw .invalidParams(method: method, reason: "unknown ton_signData payload type: \(param.type)")
        }
    }

    func decodeFirstParam(
        from paramsJSON: String,
        method: WalletConnectMethod
    ) throws(WalletConnectRequestParsingError) -> Param {
        let data = try utilities.paramsData(paramsJSON: paramsJSON, method: method)
        let decoder = JSONDecoder()

        do {
            if let direct = try decoder.decode([Param].self, from: data).first {
                return direct
            }
            throw WalletConnectRequestParsingError.invalidParams(
                method: method,
                reason: "params array is empty"
            )
        } catch let error as WalletConnectRequestParsingError {
            throw error
        } catch {
            do {
                guard let paramJSON = try decoder.decode([String].self, from: data).first,
                      let paramData = paramJSON.data(using: .utf8)
                else {
                    throw WalletConnectRequestParsingError.invalidParams(
                        method: method,
                        reason: "params array is empty"
                    )
                }
                return try decoder.decode(Param.self, from: paramData)
            } catch let fallbackError as WalletConnectRequestParsingError {
                throw fallbackError
            } catch {
                throw .invalidParams(method: method, reason: "failed to decode ton_signData params: \(error.logDescription)")
            }
        }
    }
}
