import Foundation
import BleTransport
import TonSwift
import BigInt
import CryptoKit

public class TonTransport {
  private let transport: BleTransportProtocol
  private let lockQueue = DispatchQueue(label: "TonTransportQueue")
  
  static let LEDGER_SYSTEM: UInt8 = 0xB0
  static let LEDGER_CLA: UInt8 = 0xE0
  static let INS_VERSION: UInt8 = 0x03
  static let INS_OPEN_APP: UInt8 = 0xd8
  static let INS_ADDRESS: UInt8 = 0x05
  static let INS_SIGN_TX: UInt8 = 0x06
  static let INS_PROOF: UInt8 = 0x08
  static let INS_SIGN_DATA: UInt8 = 0x09
  
  public static func isVersion(_ version: String, greaterThanOrEqualTo targetVersion: String) -> Bool {
    return version.compare(targetVersion, options: .numeric) != .orderedAscending
  }
  
  public init(transport: BleTransportProtocol) {
    self.transport = transport
  }
  
  private func chunks(buf: Data, n: Int) -> [Data] {
    let nc = Int(ceil(Double(buf.count) / Double(n)))
    var cs = [Data]()
    for i in 0..<nc {
      let start = i * n
      let end = min((i + 1) * n, buf.count)
      let chunk = buf.subdata(in: start..<end)
      cs.append(chunk)
    }
    return cs
  }
  
  private func doRequest(ins: UInt8, p1: UInt8, p2: UInt8, data: Data) async throws -> Data {
    return try await withCheckedThrowingContinuation { continuation in
      lockQueue.async {
        Task {
          do {
            let response = try await self.transport.send(system: TonTransport.LEDGER_CLA, command: ins, p1: p1, p2: p2, data: data, responseCodes: nil)
            let result = response.subdata(in: 0..<response.count - 2)
            continuation.resume(returning: result)
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }
  }
  
  private func getCurrentApp() async throws -> (String, String) {
    return try await withCheckedThrowingContinuation { continuation in
      lockQueue.async {
        Task {
          do {
            let response = try await self.transport.send(system: TonTransport.LEDGER_SYSTEM, command: 0x01, p1: 0x00, p2: 0x00, data: Data(), responseCodes: nil)
            
            let data = response.subdata(in: 0..<(response.count - 2))
            
            guard data[0] == 0x01 else {
              throw NSError(domain: "TonTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            let nameLength = Int(data[1])
            let nameData = data.subdata(in: 2..<(2 + nameLength))
            let name = String(data: nameData, encoding: .utf8) ?? ""
            let versionLength = Int(data[2 + nameLength])
            let versionData = data.subdata(in: (3 + nameLength)..<(3 + nameLength + versionLength))
            let version = String(data: versionData, encoding: .utf8) ?? ""
            let result = (name, version)
            continuation.resume(returning: result)
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }
  }
  
  public func isAppOpen() async throws -> (Bool, String) {
    let (app, version) = try await getCurrentApp()
    
    switch app {
    case "TON":
      return (true, version)
    case "BOLOS":
      do {
        let _ = try await doRequest(ins: TonTransport.INS_OPEN_APP, p1: 0x00, p2: 0x00, data: Data("TON".utf8))
      } catch {}
      return (false, "")
    default:
      return (false, "")
    }
  }
  
  public func getVersion() async throws -> String {
    let loaded = try await doRequest(ins: TonTransport.INS_VERSION, p1: 0x00, p2: 0x00, data: Data())
    
    guard loaded.count >= 3 else {
      throw NSError(domain: "TonTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
    
    let major = Int(loaded[0])
    let minor = Int(loaded[1])
    let patch = Int(loaded[2])
    
    return "\(major).\(minor).\(patch)"
  }
  
  public func getAccount(path: AccountPath) async throws -> LedgerAccount {
    // Get public key
    let response = try await doRequest(ins: TonTransport.INS_ADDRESS, p1: 0x00, p2: 0x00, data: path.data)
    if response.count != 32 {
      throw NSError(domain: "TonTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
    
    let publicKey = PublicKey(data: response)
    
    return LedgerAccount(publicKey: publicKey, revision: .v4R2, path: path)
  }
  
  public func signTransaction(path: AccountPath, transaction: Transaction) async throws -> Cell {
    let account = try await getAccount(path: path)
    let publicKey = account.publicKey
    
    let timeout = transaction.timeout ?? UInt64(Date().timeIntervalSince1970) + 60
    
    var pkg = [UInt8]()
    pkg += putUint8(0)
    pkg += putUint32(transaction.seqno)
    pkg += putUint32(timeout)
    pkg += try putVarUInt(transaction.coins.rawValue)
    pkg += putAddress(transaction.destination)
    pkg += putUint8(transaction.bounceable ? 1 : 0)
    pkg += putUint8(transaction.sendMode.rawValue)
    
    var stateInit: Cell? = nil
    if let transactionStateInit = transaction.stateInit {
      let builder = Builder()
      try transactionStateInit.storeTo(builder: builder)
      stateInit = try builder.endCell()
      if let stateInit = stateInit {
        pkg += putUint8(1)
        pkg += putUint16(Int(stateInit.depth()))
        pkg += stateInit.hash()
      }
    } else {
      pkg += putUint8(0)
    }
    
    var payload: Cell?
    var hints = putUint8(0)
    
    switch transaction.payload {
    case .comment(let text):
      let comment = Data(text.utf8)
      hints = putUint8(1) + putUint32(0x00) + putUint16(comment.count) + comment
      payload = try Builder().store(int: 0, bits: 32).writeSnakeData(comment).endCell()
      
    case .jettonTransfer(let jettonPayload):
      hints = putUint8(1) + putUint32(0x01)
      let builder = try Builder().store(uint: 0x0f8a7ea5, bits: 32)
      var bytes = [UInt8]()
      
      if let queryId = jettonPayload.queryId {
        bytes += putUint8(1) + (try putUint64(queryId))
        try builder.store(uint: queryId, bits: 64)
      } else {
        bytes += putUint8(0)
        try builder.store(uint: 0, bits: 64)
      }
      
      bytes += try putVarUInt(jettonPayload.coins.rawValue) + putAddress(jettonPayload.receiverAddress) + putAddress(jettonPayload.excessesAddress)
      try jettonPayload.coins.storeTo(builder: builder)
      try jettonPayload.receiverAddress.storeTo(builder: builder)
      try jettonPayload.excessesAddress.storeTo(builder: builder)
      
      if let cellRef = jettonPayload.customPayload {
        bytes += putUint8(1) + putCellRef(cellRef)
        try builder.storeMaybe(ref: cellRef)
      } else {
        bytes += putUint8(0)
        try builder.store(bit: false)
      }
      
      bytes += try putVarUInt(jettonPayload.forwardAmount.rawValue)
      try jettonPayload.forwardAmount.storeTo(builder: builder)
      
      if let cellRef = jettonPayload.forwardPayload {
        bytes += putUint8(1) + putCellRef(cellRef)
        try builder.storeMaybe(ref: cellRef)
      } else {
        bytes += putUint8(0)
        try builder.store(bit: false)
      }
      
      payload = try builder.endCell()
      hints += putUint16(bytes.count) + bytes
      
    case .nftTransfer(let nftPayload):
      hints = putUint8(1) + putUint32(0x02)
      let builder = try Builder().store(uint: 0x5fcc3d14, bits: 32)
      var bytes = [UInt8]()
      
      if let queryId = nftPayload.queryId {
        bytes += putUint8(1) + (try putUint64(queryId))
        try builder.store(uint: queryId, bits: 64)
      } else {
        bytes += putUint8(0)
        try builder.store(uint: 0, bits: 64)
      }
      
      bytes += putAddress(nftPayload.newOwnerAddress) + putAddress(nftPayload.excessesAddress)
      try nftPayload.newOwnerAddress.storeTo(builder: builder)
      try nftPayload.excessesAddress.storeTo(builder: builder)
      
      if let cellRef = nftPayload.customPayload {
        bytes += putUint8(1) + putCellRef(cellRef)
        try builder.storeMaybe(ref: cellRef)
      } else {
        bytes += putUint8(0)
        try builder.store(bit: false)
      }
      
      bytes += try putVarUInt(nftPayload.forwardAmount.rawValue)
      try nftPayload.forwardAmount.storeTo(builder: builder)
      
      if let cellRef = nftPayload.forwardPayload {
        bytes += putUint8(1) + putCellRef(cellRef)
        try builder.storeMaybe(ref: cellRef)
      } else {
        bytes += putUint8(0)
        try builder.store(bit: false)
      }
      
      payload = try builder.endCell()
      hints += putUint16(bytes.count) + bytes
      
    case .none: break
    }
    
    if let payload {
      pkg += putUint8(1) + putUint16(Int(payload.depth())) + payload.hash().toByteArray() + hints
    } else {
      pkg += putUint8(0) + putUint8(0)
    }
    
    _ = try await doRequest(ins: TonTransport.INS_SIGN_TX, p1: 0x00, p2: 0x03, data: path.data)
    let pkgChunks = chunks(buf: Data(pkg), n: 255)
    for chunk in pkgChunks.dropLast() {
      _ = try await doRequest(ins: TonTransport.INS_SIGN_TX, p1: 0x00, p2: 0x02, data: Data(chunk))
    }
    let res = try await doRequest(ins: TonTransport.INS_SIGN_TX, p1: 0x00, p2: 0x00, data: Data(pkgChunks.last!))
    
    let orderBuilder = try Builder()
      .store(bit: false)
      .store(bit: true)
      .store(bit: transaction.bounceable)
      .store(bit: false)
      .store(uint: 0, bits: 2)
    try transaction.destination.storeTo(builder: orderBuilder)
    try transaction.coins.storeTo(builder: orderBuilder)
    try orderBuilder.store(bit: false)
    try Coins(rawValue: BigUInt(0))?.storeTo(builder: orderBuilder)
    try Coins(rawValue: BigUInt(0))?.storeTo(builder: orderBuilder)
    try orderBuilder.store(uint: 0, bits: 64)
    try orderBuilder.store(uint: 0, bits: 32)
    if let stateInit {
      try orderBuilder.store(bit: true)
      try orderBuilder.store(bit: true)
      try orderBuilder.store(ref: stateInit)
    } else {
      try orderBuilder.store(bit: false)
    }
    if let payload {
      try orderBuilder.store(bit: true)
      try orderBuilder.store(ref: payload)
    } else {
      try orderBuilder.store(bit: false)
    }
    
    let transfer = try Builder()
      .store(uint: 698983191, bits: 32)
      .store(uint: timeout, bits: 32)
      .store(uint: transaction.seqno, bits: 32)
      .store(uint: 0, bits: 8)
      .store(uint: transaction.sendMode.rawValue, bits: 8)
      .store(ref: orderBuilder.endCell())
      .endCell()
    
    let signature = res.subdata(in: 1..<65)
    let hash = res.subdata(in: 66..<98)
    
    if !hash.elementsEqual(transfer.hash()) {
      throw NSError(domain: "TonTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Hash mismatch. Expected: \(transfer.hash().hexString()), got: \(hash.hexString())"])
    }
    
    let isValidSignature = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey.data).isValidSignature(signature, for: hash)
    
    if !isValidSignature {
      throw NSError(domain: "TonTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Received signature is invalid"])
    }
    
    return try Builder()
      .store(data: signature)
      .store(slice: transfer.beginParse())
      .endCell()
  }
}

private extension TonTransport {
  func putUint32(_ value: UInt64) -> [UInt8] {
    let byteArray = withUnsafeBytes(of: value.bigEndian, Array.init)
    return Array(byteArray.suffix(4))
  }
  
  func putUint16(_ value: Int) -> [UInt8] {
    let byteArray = withUnsafeBytes(of: UInt16(value).bigEndian, Array.init)
    return Array(byteArray.suffix(2))
  }
  
  func putUint64(_ value: BigUInt) throws -> [UInt8] {
    return try Builder().store(biguint: value, bits: 64).endCell().bits.bitsToPaddedBuffer().toByteArray()
  }
  
  func putVarUInt(_ value: BigUInt) throws -> [UInt8] {
    let sizeBytes = value == 0 ? 0 : Int(ceil(Double(value.bitWidth) / 8.0))
    let cell = try Builder().store(uint: sizeBytes, bits: 8).store(uint: value, bits: sizeBytes * 8).endCell()
    return try cell.beginParse().loadBits(8 + sizeBytes * 8).bitsToPaddedBuffer().toByteArray()
  }
  
  func putUint8(_ value: UInt8) -> [UInt8] {
    return [value]
  }
  
  func putAddress(_ address: Address) -> [UInt8] {
    let workchainIdByte = address.workchain == -1 ? UInt8(0xff) : UInt8(address.workchain)
    return putUint8(workchainIdByte) + address.hash.toByteArray()
  }
  
  func putCellRef(_ ref: Cell) -> [UInt8] {
    return putUint16(Int(ref.depth())) + ref.hash()
  }
}

private extension Data {
  func toByteArray() -> [UInt8] {
    return self.withUnsafeBytes {
      Array(UnsafeBufferPointer<UInt8>(start: $0.bindMemory(to: UInt8.self).baseAddress, count: self.count))
    }
  }
}
