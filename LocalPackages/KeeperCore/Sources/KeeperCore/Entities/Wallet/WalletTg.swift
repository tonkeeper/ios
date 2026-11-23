import Foundation
import TonSwift

/// Telegram wallet: https://docs.ton.org/contracts/standard/wallets/telegram/messages
///
/// The account holds only a trampoline; validators supply the wallet logic from config param -123 and may change it,
/// so its fees come from emulation rather than local gas figures.
public struct WalletTg: WalletContract {
    public static let mainnetSubwalletId: UInt32 = 0x7FFF_7F11
    public static let testnetSubwalletId: UInt32 = 0x7FFF_7FFD

    // swiftlint:disable:next force_try
    public static let code: Cell = try! Cell.fromBoc(
        src: Data(hex: "b5ee9c7241010101001a000030ff00209821d7498308b9f240df8085f833d0ed1e20ed53d969427e39")!
    )[0]

    public let workchain: Int8 = 0
    public let publicKey: Data
    public let subwalletId: UInt32
    public let maxMessages: Int = 255

    public init(publicKey: Data, network: Network) {
        self.publicKey = publicKey
        self.subwalletId = network == .mainnet ? Self.mainnetSubwalletId : Self.testnetSubwalletId
    }

    public var stateInit: StateInit {
        // swiftlint:disable:next force_try
        let data = try! Builder()
            .store(uint: 0, bits: 8)
            .store(uint: 0, bits: 32)
            .store(uint: subwalletId, bits: 32)
            .store(data: publicKey)
            .endCell()
        // StateInit's memberwise initializer is internal to TonSwift: split_depth and special are absent,
        // code and data are refs, libraries is an empty dictionary.
        // swiftlint:disable:next force_try
        let cell = try! Builder()
            .store(bit: false)
            .store(bit: false)
            .storeMaybe(ref: Self.code)
            .storeMaybe(ref: data)
            .store(bit: false)
            .endCell()
        // swiftlint:disable:next force_try
        return try! StateInit.loadFrom(slice: cell.beginParse())
    }

    public func createTransfer(args: WalletTransferData, messageType: MessageType) throws -> WalletTransfer {
        let validUntil = args.timeout ?? UInt64(Date().timeIntervalSince1970) + 60
        let signingMessage = try createRequestBody(
            validUntil: validUntil,
            seqno: args.seqno,
            messageType: messageType,
            messages: args.messages.map { try MessageToSend(sendMode: args.sendMode.rawValue, message: $0) }
        )
        return WalletTransfer(signingMessage: signingMessage, signaturePosition: .front)
    }

    public struct MessageToSend {
        public let sendMode: UInt8
        public let cell: Cell

        public init(sendMode: UInt8, cell: Cell) {
            self.sendMode = sendMode
            self.cell = cell
        }

        init(sendMode: UInt8, message: MessageRelaxed) throws {
            try self.init(sendMode: sendMode, cell: Builder().store(message).endCell())
        }
    }

    public func createRequestBody(
        validUntil: UInt64,
        seqno: UInt64,
        messageType: MessageType,
        messages: [MessageToSend]
    ) throws -> Builder {
        guard (1 ... maxMessages).contains(messages.count) else {
            throw TonError.custom("WalletTg sends from 1 to \(maxMessages) messages, got \(messages.count)")
        }
        // An external request without the ignore-errors mode is rejected with exit code 137.
        guard messageType == .int || messages.allSatisfy({ $0.sendMode & Self.sendModeIgnoreErrors != 0 }) else {
            throw TonError.custom("WalletTg requires the ignore-errors send mode in external requests")
        }

        let isSingle = messages.count == 1
        let opCode: UInt32 = switch (isSingle, messageType) {
        case (true, .int): Self.sendOneInternal
        case (true, .ext): Self.sendOneExternal
        case (false, .int): Self.sendBulkInternal
        case (false, .ext): Self.sendBulkExternal
        }

        let builder = try Builder()
            .store(uint: opCode, bits: 32)
            .store(uint: subwalletId, bits: 32)
            .store(uint: validUntil, bits: 32)
            .store(uint: seqno, bits: 32)
        if isSingle {
            try store(message: messages[0], to: builder)
        } else {
            try store(messages: messages, to: builder)
        }
        return builder
    }
}

private extension WalletTg {
    static let sendOneInternal: UInt32 = 0x6389_6E74
    static let sendOneExternal: UInt32 = 0x6389_6E75
    static let sendBulkInternal: UInt32 = 0x7389_6E74
    static let sendBulkExternal: UInt32 = 0x7389_6E75

    static let sendModeIgnoreErrors: UInt8 = 2
    static let cellRefsLimit = 4

    /// Tolk array<MessageToSend>: len:uint8 head:(Maybe ^Chunk), Chunk = next:(Maybe ^Chunk) items.
    /// Chunks are filled from the tail, so only the head chunk may be partial.
    func store(messages: [MessageToSend], to builder: Builder) throws {
        try builder.store(uint: UInt64(messages.count), bits: 8)
        var next: Cell?
        var rest = messages[...]
        while !rest.isEmpty {
            let capacity = next == nil ? Self.cellRefsLimit : Self.cellRefsLimit - 1
            let size = min(rest.count, capacity)
            let chunk = Builder()
            try chunk.storeMaybe(ref: next)
            for message in rest.suffix(size) {
                try store(message: message, to: chunk)
            }
            rest = rest.dropLast(size)
            next = try chunk.endCell()
        }
        try builder.storeMaybe(ref: next)
    }

    func store(message: MessageToSend, to builder: Builder) throws {
        try builder.store(uint: message.sendMode, bits: 8)
        try builder.store(ref: message.cell)
    }
}
