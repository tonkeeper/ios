import BigInt
import ChainKit
import Foundation
import TKLogging

struct PerpsBitcoinDeposit: Sendable, Equatable {
    let sentUnits: BigUInt
    let feeUnits: BigUInt
    let virtualSize: BigUInt
}

enum PerpsBitcoinDepositReader {
    /// ×3 rather than the ticket's ×2, so that honest deposits always go through: Relay pays the miners more than the
    /// wallet would, and at ×2 a dip in the wallet's own estimate is enough to refuse them.
    static let maxFeeRateMultiplier: BigUInt = 3

    private static let maxShortfallBps: BigUInt = 100
    private static let sighashDefault: Int64 = 0
    private static let sighashAll: Int64 = 1
    private static let opReturn: UInt8 = 0x6A
    private static let opPushdata1: UInt8 = 0x4C
    private static let maxDirectPush: UInt8 = 0x4B
    private static let versionAndLockTimeBytes = 8
    private static let inputBytes = 41
    private static let outputValueBytes = 8
    private static let segwitMarkerAndFlagWeight = 2
    private static let p2wpkhWitnessWeight = 109
    private static let p2trWitnessWeight = 67
    private static let witnessScale = 4

    static func read(
        _ quote: PerpsDepositQuote,
        budget: BigUInt,
        security: PerpsSecurityConfig?
    ) throws(PerpsDepositQuoteError) -> PerpsBitcoinDeposit {
        guard quote.provider == .relay else { throw refusal("provider") }
        guard let depositories = security?.relayBitcoinDepositories, !depositories.isEmpty else {
            throw refusal("relay depository")
        }
        let payloads = try quote.operation.parsed().payloads
        guard payloads.count == 1, let payload = payloads.first,
              payload.version == 1, payload.chain.caip2 == MultichainChain.btc.asChainKitChain.caip2
        else { throw refusal("payloads") }
        guard case .prebuild = payload.type, let psbt = payload.meta as? PayloadMetaBitcoinPrebuild else {
            throw refusal("payload")
        }
        guard let inputs = psbt.inputs(chain: payload.chain).getOrNull() as? [PsbtInput],
              let outputs = psbt.outputs(chain: payload.chain).getOrNull() as? [PsbtOutput]
        else { throw refusal("psbt") }
        guard let owner = PerpsFundingAssetId.bitcoinAddress(quote.sender) else { throw refusal("sender") }

        var spent = [PsbtOutput]()
        for input in inputs {
            guard let coin = input.spent, Self.owner(of: coin) == owner else { throw refusal("input") }
            if let sighash = input.sighash?.int64Value,
               sighash != sighashAll, !(sighash == sighashDefault && isTaproot(coin))
            {
                throw refusal("sighash")
            }
            spent.append(coin)
        }

        var deposits = [PsbtOutput]()
        var change = [PsbtOutput]()
        var others = [PsbtOutput]()
        for output in outputs {
            let address = Self.owner(of: output)
            if let address, depositories.contains(address) {
                deposits.append(output)
            } else if address == owner {
                change.append(output)
            } else {
                others.append(output)
            }
        }
        guard deposits.count == 1, let deposit = deposits.first else { throw refusal("depository output") }
        guard change.count <= 1 else { throw refusal("change output") }
        guard others.count == 1, let order = others.first else { throw refusal("outputs") }
        guard try units(order.value) == 0, carriesOrderId(order) else { throw refusal("op_return") }

        let sent = try units(deposit.value)
        guard sent > 0, sent <= budget, sent * 10000 >= budget * (10000 - maxShortfallBps) else {
            throw refusal("value")
        }

        var inputTotal = BigUInt(0)
        for coin in spent {
            inputTotal += try units(coin.value)
        }
        var outputTotal = BigUInt(0)
        for output in outputs {
            outputTotal += try units(output.value)
        }
        guard inputTotal >= outputTotal else { throw refusal("fee") }

        return try PerpsBitcoinDeposit(
            sentUnits: sent,
            feeUnits: inputTotal - outputTotal,
            virtualSize: virtualSize(spent: spent, outputs: outputs)
        )
    }

    static func checkFeeRate(_ deposit: PerpsBitcoinDeposit, walletBytePrice: BigUInt?) throws(PerpsDepositQuoteError) {
        guard let walletBytePrice, walletBytePrice > 0 else { throw refusal("wallet fee rate") }
        guard deposit.feeUnits <= walletBytePrice * maxFeeRateMultiplier * deposit.virtualSize else {
            throw refusal("fee rate")
        }
    }

    private static func virtualSize(spent: [PsbtOutput], outputs: [PsbtOutput]) throws(PerpsDepositQuoteError) -> BigUInt {
        var outputBytes = 0
        for output in outputs {
            let scriptBytes = output.script.count / 2
            outputBytes += outputValueBytes + compactSizeBytes(scriptBytes) + scriptBytes
        }
        let baseBytes = versionAndLockTimeBytes
            + compactSizeBytes(spent.count) + spent.count * inputBytes
            + compactSizeBytes(outputs.count) + outputBytes
        var witnessWeight = segwitMarkerAndFlagWeight
        for coin in spent {
            if isP2WPKH(coin) {
                witnessWeight += p2wpkhWitnessWeight
            } else if isTaproot(coin) {
                witnessWeight += p2trWitnessWeight
            } else {
                throw refusal("input")
            }
        }
        return BigUInt((baseBytes * witnessScale + witnessWeight + witnessScale - 1) / witnessScale)
    }

    private static func compactSizeBytes(_ value: Int) -> Int {
        switch value {
        case ...0xFC: 1
        case ...0xFFFF: 3
        default: 5
        }
    }

    private static func isP2WPKH(_ output: PsbtOutput) -> Bool {
        isScript(output, prefix: "0014", bytes: 20)
    }

    private static func isTaproot(_ output: PsbtOutput) -> Bool {
        isScript(output, prefix: "5120", bytes: 32)
    }

    private static func isScript(_ output: PsbtOutput, prefix: String, bytes: Int) -> Bool {
        let script = output.script.lowercased()
        return script.count == prefix.count + bytes * 2 && script.hasPrefix(prefix) && script.allSatisfy(\.isHexDigit)
    }

    private static func owner(of output: PsbtOutput) -> String? {
        output.address.flatMap { PerpsFundingAssetId.bitcoinAddress($0.display) }
    }

    private static func carriesOrderId(_ output: PsbtOutput) -> Bool {
        guard output.address == nil, let bytes = hexBytes(output.script), bytes.count >= 2, bytes[0] == opReturn else {
            return false
        }
        let length: Int
        let start: Int
        switch bytes[1] {
        case 1 ... maxDirectPush:
            (length, start) = (Int(bytes[1]), 2)
        case opPushdata1:
            guard bytes.count >= 3 else { return false }
            (length, start) = (Int(bytes[2]), 3)
        default:
            return false
        }
        guard bytes.count == start + length else { return false }
        let text = bytes[start...]
        return text.count == 66 && text.prefix(2) == [0x30, 0x78]
            && text.dropFirst(2).allSatisfy { $0 < 0x80 && Character(Unicode.Scalar($0)).isHexDigit }
    }

    private static func hexBytes(_ hex: String) -> [UInt8]? {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    private static func units(_ value: BignumBigInteger) throws(PerpsDepositQuoteError) -> BigUInt {
        guard let units = BigUInt(value.description, radix: 10) else { throw refusal("value") }
        return units
    }

    private static func refusal(_ field: String) -> PerpsDepositQuoteError {
        Log.perps.w("Deposit from Bitcoin refused: \(field)")
        return .unexpectedBitcoinPayment(field)
    }
}
