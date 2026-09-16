import Foundation

struct WalletConnectTONSendMessageParser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain _: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let method: WalletConnectMethod = .tonSendMessage
        let param = try decodeFirstParam(
            from: paramsJSON,
            method: method
        )

        guard !param.messages.isEmpty else {
            throw .invalidParams(method: method, reason: "ton_sendMessage requires at least one message")
        }

        return .tonSendMessage(
            WalletConnectTONSendMessage(
                from: param.from,
                messagesCount: param.messages.count,
                rawParamsJSON: paramsJSON
            )
        )
    }
}

private extension WalletConnectTONSendMessageParser {
    struct Param: Decodable {
        var from: String?
        var messages: [Message]

        enum CodingKeys: String, CodingKey {
            case from
            case source
            case messages
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            from = try container.decodeIfPresent(String.self, forKey: .from)
                ?? container.decodeIfPresent(String.self, forKey: .source)
            messages = try container.decode([Message].self, forKey: .messages)
        }
    }

    struct Message: Decodable {
        var address: String
        var amount: Amount
        var stateInit: String?
        var payload: String?
    }

    struct Amount: Decodable {
        var value: String

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                value = string
            } else if let uint = try? container.decode(UInt64.self) {
                value = "\(uint)"
            } else {
                let int = try container.decode(Int64.self)
                guard int >= 0 else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "amount must not be negative"
                    )
                }
                value = "\(int)"
            }
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
                throw .invalidParams(method: method, reason: "failed to decode ton_sendMessage params: \(error.logDescription)")
            }
        }
    }
}
