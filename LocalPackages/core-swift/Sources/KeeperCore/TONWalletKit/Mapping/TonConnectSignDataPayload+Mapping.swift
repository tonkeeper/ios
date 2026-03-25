import Foundation
import TONWalletKit

public extension TonConnectSignDataPayload {
    init(data: TONSignData) {
        switch data {
        case let .text(textData):
            self = .text(text: textData.content)
        case let .binary(binaryData):
            self = .binary(bytes: binaryData.content.value)
        case let .cell(cellData):
            self = .cell(schema: cellData.schema, cell: cellData.content.value)
        }
    }
}
