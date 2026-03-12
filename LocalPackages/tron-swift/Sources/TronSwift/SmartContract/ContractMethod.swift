import Foundation

public protocol ContractMethod {
    var signature: String { get }
    var arguments: [Parameter] { get }
}

public extension ContractMethod {
    func encode() -> Data {
        ContractCoding.encode(methodId: ContractCoding.methodId(signature: signature), parameters: arguments)
    }
}
