import BigInt
import Foundation
import TonSwift

private let GAS_SAFETY_MULTIPLIER: BigUInt = 105
private let GAS_SAFETY_MULTIPLIER_DENOMINATOR: BigUInt = 100

public struct BlockchainConfig {
    public let msgForwardPrices: MsgForwardPrices?
    public let gasLimitsPrices: GasLimitsPrices?

    public init(msgForwardPrices: MsgForwardPrices? = nil, gasLimitsPrices: GasLimitsPrices? = nil) {
        self.msgForwardPrices = msgForwardPrices
        self.gasLimitsPrices = gasLimitsPrices
    }
}

public struct MsgForwardPrices {
    public let bitPrice: UInt64
    public let cellPrice: UInt64
    public let lumpPrice: UInt64

    /// Current values from blockchain config. We should retrieve them from the /v2/blockchain/config endpoint during implementation
    public init(bitPrice: UInt64 = 26_214_400, cellPrice: UInt64 = 2_621_440_000, lumpPrice: UInt64 = 400_000) {
        self.bitPrice = bitPrice
        self.cellPrice = cellPrice
        self.lumpPrice = lumpPrice
    }
}

public struct GasLimitsPrices {
    public let gasPrice: UInt64

    public init(gasPrice: UInt64 = 26_214_400) {
        self.gasPrice = gasPrice
    }
}

public struct ITxData {
    public let inMsgBocHex: String
    public let outMsgBocHex: String
    public let walletVersion: WalletContractVersion

    public init(inMsgBocHex: String, outMsgBocHex: String, walletVersion: WalletContractVersion) {
        self.inMsgBocHex = inMsgBocHex
        self.outMsgBocHex = outMsgBocHex
        self.walletVersion = walletVersion
    }
}

// TODO: not using now, should migrate validateFundsIfNeeded to it
public func estimateWalletContractExecutionGasFee(config: BlockchainConfig, data: ITxData) throws -> BigUInt {
    let inMsgBocHex = data.inMsgBocHex
    let outMsgBocHex = data.outMsgBocHex
    let walletVersion = data.walletVersion

    let msgForwardPrices = config.msgForwardPrices ?? MsgForwardPrices()
    let bitPrice = msgForwardPrices.bitPrice
    let cellPrice = msgForwardPrices.cellPrice
    let lumpPrice = msgForwardPrices.lumpPrice

    let timeChunk: UInt64 = 65536
    let msgFwdBitPrice = bitPrice
    let msgFwdCellPrice = cellPrice
    let gasPrice = (config.gasLimitsPrices?.gasPrice ?? 26_214_400) / timeChunk

    func computeMsgFwdFee(msgBits: UInt64, msgCells: UInt64) -> UInt64 {
        let bitsPrice = msgFwdBitPrice * msgBits
        let cellsPrice = msgFwdCellPrice * msgCells

        return lumpPrice + UInt64(ceil(Double(bitsPrice + cellsPrice) / Double(timeChunk)))
    }

    func computeGasFee(version: WalletContractVersion) throws -> UInt64 {
        let gasUsed: UInt64
        switch version {
        case .v4R2:
            gasUsed = 6615
        case .v5Beta, .v5R1:
            gasUsed = 8444
        default:
            throw GasFeeError.unknownWalletVersion(version)
        }

        return gasUsed * gasPrice
    }

    func computeImportFee(msgBits: UInt64, msgCells: UInt64) -> UInt64 {
        return lumpPrice + UInt64(ceil(Double(msgFwdBitPrice * msgBits + msgFwdCellPrice * msgCells) / Double(timeChunk)))
    }

    func countBitsAndCellsInMsg(msg: Cell, hashes: inout Set<Data>) -> (bits: UInt64, cells: UInt64) {
        let hash = msg.hash()
        let initialSize = hashes.count

        hashes.insert(hash)

        if hashes.count == initialSize {
            return (0, 0)
        }

        var cells: UInt64 = 1
        var bits: UInt64 = UInt64(msg.bits.length)

        for ref in msg.refs {
            let (innerBits, innerCells) = countBitsAndCellsInMsg(msg: ref, hashes: &hashes)
            bits += innerBits
            cells += innerCells
        }

        return (bits, cells)
    }

    guard let inMsgData = Data(hex: inMsgBocHex) else {
        throw GasFeeError.invalidHexString("inMsgBocHex")
    }

    let inMsgs = try Cell.fromBoc(src: inMsgData)
    guard inMsgs.count == 1 else {
        throw GasFeeError.multipleInboundMessages
    }

    var inMsgHashes = Set<Data>()
    var msgBits: UInt64 = 0
    var msgCells: UInt64 = 0

    let inMsg = inMsgs[0]
    for ref in inMsg.refs {
        let (innerMsgBits, innerMsgCells) = countBitsAndCellsInMsg(msg: ref, hashes: &inMsgHashes)
        msgBits += innerMsgBits
        msgCells += innerMsgCells
    }

    guard let outMsgData = Data(hex: outMsgBocHex) else {
        throw GasFeeError.invalidHexString("outMsgBocHex")
    }

    let outMsgs = try Cell.fromBoc(src: outMsgData)
    guard outMsgs.count == 1 else {
        throw GasFeeError.multipleOutboundMessages
    }

    var fwdMsgBits: UInt64 = 0
    var fwdMsgCells: UInt64 = 0
    let outMsg = outMsgs[0]
    var fwdMsgHashes = Set<Data>()

    for ref in outMsg.refs {
        let (innerFwdMsgBits, innerFwdMsgCells) = countBitsAndCellsInMsg(msg: ref, hashes: &fwdMsgHashes)
        fwdMsgBits += innerFwdMsgBits
        fwdMsgCells += innerFwdMsgCells
    }

    let msgFwdFee = computeMsgFwdFee(msgBits: fwdMsgBits, msgCells: fwdMsgCells)
    let gasFee = try computeGasFee(version: walletVersion)
    let importFee = computeImportFee(msgBits: msgBits, msgCells: msgCells)

    let base = BigUInt(msgFwdFee + gasFee + importFee)

    return (base * GAS_SAFETY_MULTIPLIER) / GAS_SAFETY_MULTIPLIER_DENOMINATOR
}

public enum GasFeeError: Error {
    case unknownWalletVersion(WalletContractVersion)
    case invalidHexString(String)
    case multipleInboundMessages
    case multipleOutboundMessages
}
