import Foundation
import TronSwift

public enum ContractCallRequest {
    public static func request(contractAddress: Address, data: Data) -> JSONRpcRequest {
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
