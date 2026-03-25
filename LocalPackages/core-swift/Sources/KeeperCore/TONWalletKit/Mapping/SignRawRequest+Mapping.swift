import Foundation
import TonSwift
import TONWalletKit

public extension SignRawRequest {
    init?(request: TONTransactionRequest) {
        do {
            let messages = try request.messages.map { try SignRawRequestMessage(message: $0) }

            var address: Address?

            if let fromAddress = request.fromAddress {
                address = try Address.parse(fromAddress)
            }

            let validUntil = request.validUntil.flatMap { UInt64($0) }

            self = Self(
                messages: messages,
                validUntil: validUntil,
                from: address,
                messagesVariants: nil
            )
        } catch {
            return nil
        }
    }
}

public extension SignRawRequestMessage {
    init(message: TONTransactionRequestMessage) throws {
        let amount = UInt64(message.amount.nanoUnits)
        let address = try AnyAddress(rawAddress: message.address)

        self = Self(
            address: address,
            amount: amount,
            stateInit: message.stateInit?.value,
            payload: message.payload?.value
        )
    }
}
