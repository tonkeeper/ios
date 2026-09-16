import TonSwift

enum TransferPayloadExcessAddressRewriter {
    static func rewrite(
        payload: Cell,
        excessAddress: Address
    ) throws -> Cell {
        let payloadSlice = try payload.toSlice()
        guard let opcode = try? payloadSlice.loadUint(bits: 32),
              opcode <= Int32.max
        else {
            return payload
        }

        let builder = Builder()
        switch Int32(opcode) {
        case OpCodes.JETTON_TRANSFER:
            try builder.store(uint: opcode, bits: 32)
            try builder.store(uint: payloadSlice.loadUint(bits: 64), bits: 64)
            try builder.store(payloadSlice.loadCoins())
            try builder.store(payloadSlice.loadType() as Address)
            let _: TonSwift.AnyAddress = try payloadSlice.loadType()
        case OpCodes.NFT_TRANSFER:
            try builder.store(uint: opcode, bits: 32)
            try builder.store(uint: payloadSlice.loadUint(bits: 64), bits: 64)
            try builder.store(payloadSlice.loadType() as Address)
            let _: TonSwift.AnyAddress = try payloadSlice.loadType()
        default:
            return payload
        }

        try builder.store(excessAddress)
        try builder.store(bits: payloadSlice.loadBits(payloadSlice.remainingBits))
        while payloadSlice.remainingRefs > 0 {
            let reference = try payloadSlice.loadRef()
            try builder.store(
                ref: rewrite(payload: reference, excessAddress: excessAddress)
            )
        }
        return try builder.endCell()
    }

    static func rewrite(
        message: MessageRelaxed,
        excessAddress: Address
    ) throws -> Cell {
        let body = try rewrite(
            payload: message.body,
            excessAddress: excessAddress
        )
        let builder = Builder()
        try builder.store(message.info)

        if let stateInit = message.stateInit {
            try builder.store(bit: true)
            try builder.store(bit: true)
            try builder.store(ref: Builder().store(stateInit))
        } else {
            try builder.store(bit: false)
        }

        try builder.store(bit: true)
        try builder.store(ref: body)

        return try builder.endCell()
    }
}
