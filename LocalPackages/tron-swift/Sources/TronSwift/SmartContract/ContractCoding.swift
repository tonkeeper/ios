import CryptoSwift
import Foundation

public enum ContractCoding {
    public static func encode(methodId: Data, parameters: [Parameter]) -> Data {
        var result = methodId
        for parameter in parameters {
            result += parameter.encode()
        }
        return result
    }

    public static func encode(parameters: [Parameter]) -> Data {
        var result = Data()
        for parameter in parameters {
            result += parameter.encode()
        }
        return result
    }

    public static func methodId(signature: String) -> Data {
        signature.data(using: .ascii)!.sha3(.keccak256)[0 ... 3]
    }
}
