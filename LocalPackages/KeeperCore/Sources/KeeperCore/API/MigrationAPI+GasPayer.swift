import Foundation
import TonAPI

enum MigrationGasPayer: String, Encodable {
    case `self`
    case battery
}

struct MigrationPrepareRequestBody: Encodable {
    let from: String
    let to: String
    let currency: String?
    let publicKey: String?
    let gasPayer: MigrationGasPayer?

    enum CodingKeys: String, CodingKey {
        case from
        case to
        case currency
        case publicKey = "public_key"
        case gasPayer = "gas_payer"
    }
}

struct MigrationPrepareResponseBody: Decodable {
    let from: String
    let to: String
    let walletVersion: String
    let transactions: [MigrationTransactionBody]
    let error: String?
    let errorCode: Int64?
    let details: InsufficientFunds?

    enum CodingKeys: String, CodingKey {
        case from
        case to
        case walletVersion = "wallet_version"
        case transactions
        case error
        case errorCode = "error_code"
        case details
    }

    var isInsufficientTonConflict: Bool {
        error != nil && errorCode == 50000
    }
}

struct MigrationTransactionBody: Decodable {
    let seqno: Int
    let boc: String
    let stateInit: String?
    let messages: [MigrationOutMessage]
    let emulation: MessageConsequences
    /// Burned network fees in nanotons. Prefer this over `emulation.event.extra` —
    /// extra is "net Gram unexplained by actions" and for a GRAM sweep can approach the
    /// full balance, which must not drive Battery charge quotes or sweep gas checks.
    let gasSpent: Int64?
    let sponsored: Bool?

    enum CodingKeys: String, CodingKey {
        case seqno
        case boc
        case stateInit = "state_init"
        case messages
        case emulation
        case gasSpent = "gas_spent"
        case sponsored
    }

    var isSponsored: Bool {
        sponsored ?? false
    }

    /// Authoritative burned fee when the backend provides it; otherwise the emulation trace.
    var resolvedGasSpentNano: UInt64 {
        if let gasSpent, gasSpent > 0 {
            return UInt64(gasSpent)
        }
        return UInt64(max(emulation.trace.transaction.totalFees, 0))
    }
}

extension MigrationPrepareResponseBody {
    init?(insufficientTonError: ErrorResponse) {
        guard case let .error(statusCode, data, _, _) = insufficientTonError,
              statusCode == 409,
              let data,
              let response = try? JSONDecoder().decode(Self.self, from: data),
              response.isInsufficientTonConflict,
              response.details != nil
        else {
            return nil
        }
        self = response
    }
}

extension MigrationAPI {
    static func prepareMigrationWithRequestBuilder(
        request: MigrationPrepareRequestBody
    ) -> RequestBuilder<MigrationPrepareResponseBody> {
        let localVariablePath = "/v2/migration/prepare"
        let localVariableURLString = TonAPIAPI.basePath + localVariablePath
        let localVariableParameters = JSONEncodingHelper.encodingParameters(forEncodableObject: request)
        let localVariableUrlComponents = URLComponents(string: localVariableURLString)
        let localVariableNillableHeaders: [String: Any?] = [
            "Content-Type": "application/json",
        ]
        let localVariableHeaderParameters = APIHelper.rejectNilHeaders(localVariableNillableHeaders)
        let localVariableRequestBuilder: RequestBuilder<MigrationPrepareResponseBody>.Type =
            TonAPIAPI.requestBuilderFactory.getBuilder()
        return localVariableRequestBuilder.init(
            method: "POST",
            URLString: localVariableUrlComponents?.string ?? localVariableURLString,
            parameters: localVariableParameters,
            headers: localVariableHeaderParameters,
            requiresAuthentication: false
        )
    }
}
