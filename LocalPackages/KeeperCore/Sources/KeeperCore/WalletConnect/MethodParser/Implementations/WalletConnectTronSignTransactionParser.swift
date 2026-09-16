@preconcurrency import AnyCodable
import Foundation
import TKLogging

struct WalletConnectTronSignTransactionParser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain _: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let params = try utilities.decode(
            Params.self,
            from: paramsJSON,
            method: method
        ) { error in
            "failed to decode tron transaction: \(error)"
        }
        let transaction = params.transaction
        let txID = try normalizedTxID(
            rawDataHex: transaction.rawDataHex,
            dappTxID: transaction.txID
        )

        return .tronTransaction(
            WalletConnectTronTransaction(
                address: params.address,
                transactionJSON: transaction.json,
                rawDataHex: transaction.rawDataHex,
                txID: txID
            )
        )
    }
}

private extension WalletConnectTronSignTransactionParser {
    var method: WalletConnectMethod {
        .tronSignTransaction
    }

    func normalizedTxID(
        rawDataHex: String?,
        dappTxID: String?
    ) throws(WalletConnectRequestParsingError) -> String {
        guard let rawDataHex else {
            throw .invalidParams(method: method, reason: "tron transaction raw_data_hex is missing or invalid")
        }

        let computedTxID: String
        do {
            computedTxID = try WalletConnectTronTransactionSigner.txID(rawDataHex: rawDataHex)
        } catch {
            throw .invalidParams(method: method, reason: "tron transaction raw_data_hex is missing or invalid")
        }

        if let dappTxID,
           !dappTxID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            guard normalizedHex(dappTxID) == computedTxID else {
                throw .invalidParams(method: method, reason: "tron transaction txID does not match raw_data_hex")
            }
        }
        return computedTxID
    }

    func normalizedHex(_ value: String) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if trimmed.hasPrefix("0x") {
            return String(trimmed.dropFirst(2))
        }
        return trimmed
    }

    struct Params: Decodable {
        struct Wrap: Decodable {
            var transaction: Transaction
        }

        var address: String?
        var transaction: Transaction

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            address = try container.decodeIfPresent(String.self, forKey: .address)
            if let wrap = try? container.decode(Wrap.self, forKey: .transaction) {
                transaction = wrap.transaction
            } else {
                transaction = try container.decode(Transaction.self, forKey: .transaction)
            }
        }

        private enum CodingKeys: CodingKey {
            case address
            case transaction
        }

        struct Transaction: Decodable {
            var rawDataHex: String?
            var txID: String?
            var json: AnyCodable

            init(from decoder: Decoder) throws {
                self.json = try AnyCodable(from: decoder)

                let container: KeyedDecodingContainer<CodingKeys>
                do {
                    container = try decoder.container(keyedBy: CodingKeys.self)
                } catch {
                    rawDataHex = nil
                    txID = nil
                    Log.w("parseTronTransaction failed", error: error)
                    return
                }
                do {
                    rawDataHex = try container.decodeIfPresent(String.self, forKey: .rawDataHex)
                } catch {
                    Log.w("parseTronTransaction failed to decode raw_data_hex", error: error)
                    rawDataHex = nil
                }
                do {
                    txID = try container.decodeIfPresent(String.self, forKey: .txID)
                } catch {
                    Log.w("parseTronTransaction failed to decode txID", error: error)
                    txID = nil
                }
            }

            private enum CodingKeys: String, CodingKey {
                case rawDataHex = "raw_data_hex"
                case txID
            }
        }
    }
}
