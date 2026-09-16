import Foundation
import TronSwift

enum ContractCallRequest {
    static func request(contractAddress: Address, data: Data) -> JSONRpcRequest {
        JSONRpcRequest(
            method: "eth_call",
            params: [
                [
                    "to": contractAddress.notPrefixed().hexString(),
                    "data": data.hexString(),
                ],
                "latest",
            ]
        )
    }
}
