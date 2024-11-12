import Foundation
import BleTransport
import TonSwift
import BigInt
import CryptoKit

public struct LedgerTransfer {
  public let signingMessage: Builder
  public let package: Data
  
  public init(signingMessage: Builder, package: Data) {
    self.signingMessage = signingMessage
    self.package = package
  }
}

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
  
  public static func buildTransfer(transaction: Transaction) throws -> LedgerTransfer {
    var pkg = [UInt8]()
    pkg += putUint8(0)
    pkg += putUint32(transaction.seqno)
    pkg += putUint32(transaction.timeout)
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
      
      // Jetton Burn
    case .jettonBurn(let burnPayload):
      hints = putUint8(1) + putUint32(0x03)
      let builder = try Builder().store(uint: 0x595f07bc, bits: 32)
      var bytes = [UInt8]()
      
      if let queryId = burnPayload.queryId {
        bytes += putUint8(1) + (try putUint64(queryId))
        try builder.store(uint: queryId, bits: 64)
      } else {
        bytes += putUint8(0)
        try builder.store(uint: 0, bits: 64)
      }
      
      bytes += try putVarUInt(burnPayload.coins.rawValue) + putAddress(burnPayload.responseDestination)
      try burnPayload.coins.storeTo(builder: builder)
      try burnPayload.responseDestination.storeTo(builder: builder)
      
      if let customPayload = burnPayload.customPayload {
        switch customPayload {
        case .cellPayload(let cell):
          bytes += putUint8(1) + putCellRef(cell)
          try builder.storeMaybe(ref: cell)
        case .byteArrayPayload(let customPayloadBytes):
          bytes += putUint8(2) + putUint8(UInt8(customPayloadBytes.count)) + customPayloadBytes
          try builder.storeMaybe(ref: try Builder().store(data: customPayloadBytes).endCell())
        }
      } else {
        bytes += putUint8(0)
        try builder.store(bit: false)
      }
      
      payload = try builder.endCell()
      hints += putUint16(bytes.count) + bytes
      
      // Add Whitelist
    case .addWhitelist(let whitelistPayload):
      hints = putUint8(1) + putUint32(0x04)
      let builder = try Builder().store(uint: 0x7258a69b, bits: 32)
      var bytes = [UInt8]()
      
      if let queryId = whitelistPayload.queryId {
        bytes += putUint8(1) + (try putUint64(queryId))
        try builder.store(uint: queryId, bits: 64)
      } else {
        bytes += putUint8(0)
        try builder.store(uint: 0, bits: 64)
      }
      
      bytes += putAddress(whitelistPayload.address)
      try whitelistPayload.address.storeTo(builder: builder)
      
      payload = try builder.endCell()
      hints += putUint16(bytes.count) + bytes
      
    case .changeDNSRecord(let dnsPayload):
      hints = putUint8(1) + putUint32(0x09)
      let builder = try Builder().store(uint: 0x4eb1f0f9, bits: 32)
      var bytes = [UInt8]()
      
      if let queryId = dnsPayload.queryId {
        bytes += putUint8(1) + (try putUint64(queryId))
        try builder.store(uint: queryId, bits: 64)
      } else {
        bytes += putUint8(0)
        try builder.store(uint: 0, bits: 64)
      }
      
      switch dnsPayload.record {
      case .wallet(let walletRecord):
        try builder.store(data: "wallet".data(using: .utf8)!.sha256())
        if let wallet = walletRecord {
          bytes += putUint8(1) + putUint8(0) + putAddress(wallet.address)
          try wallet.address.storeTo(builder: builder)
          
          if let capabilities = wallet.capabilities {
            bytes += putUint8(1)
            try builder.store(bit: capabilities.isWallet)
            if capabilities.isWallet {
              try builder.store(uint: 0x2177, bits: 16)
            }
          } else {
            bytes += putUint8(0)
          }
        } else {
          bytes += putUint8(0) + putUint8(0)
        }
      case .unknown(let key, let value):
          if key.count != 32 {
            throw NSError(domain: "TonTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "DNS record key length must be 32 bytes long"])
          }
          try builder.store(data: key)
          bytes += putUint8(value != nil ? 1 : 0) + putUint8(1)
          if let recordValue = value {
              bytes += putCellRef(recordValue)
              try builder.storeMaybe(ref: recordValue)
          }
      }
      
      payload = try builder.endCell()
      hints += putUint16(bytes.count) + bytes
      
      // Single Nominator Change Validator
    case .singleNominatorChangeValidator(let nominatorPayload):
      hints = putUint8(1) + putUint32(0x06)
      let builder = try Builder().store(uint: 0x1001, bits: 32)
      var bytes = [UInt8]()
      
      if let queryId = nominatorPayload.queryId {
        bytes += putUint8(1) + (try putUint64(queryId))
        try builder.store(uint: queryId, bits: 64)
      } else {
        bytes += putUint8(0)
        try builder.store(uint: 0, bits: 64)
      }
      
      bytes += putAddress(nominatorPayload.address)
      try nominatorPayload.address.storeTo(builder: builder)
      
      payload = try builder.endCell()
      hints += putUint16(bytes.count) + bytes
      
      // Single Nominator Withdraw
    case .singleNominatorWithdraw(let withdrawPayload):
      hints = putUint8(1) + putUint32(0x05)
      let builder = try Builder().store(uint: 0x1000, bits: 32)
      var bytes = [UInt8]()
      
      if let queryId = withdrawPayload.queryId {
        bytes += putUint8(1) + (try putUint64(queryId))
        try builder.store(uint: queryId, bits: 64)
      } else {
        bytes += putUint8(0)
        try builder.store(uint: 0, bits: 64)
      }
      
      bytes += try putVarUInt(withdrawPayload.coins.rawValue)
      try withdrawPayload.coins.storeTo(builder: builder)
      
      payload = try builder.endCell()
      hints += putUint16(bytes.count) + bytes
      
      // Token Bridge Pay Swap
    case .tokenBridgePaySwap(let swapPayload):
      hints = putUint8(1) + putUint32(0x0A)
      let builder = try Builder().store(uint: 0x8, bits: 32)
      var bytes = [UInt8]()
      
      if let queryId = swapPayload.queryId {
        bytes += putUint8(1) + (try putUint64(queryId))
        try builder.store(uint: queryId, bits: 64)
      } else {
        bytes += putUint8(0)
        try builder.store(uint: 0, bits: 64)
      }
      
      if swapPayload.swapId.count != 32 {
        throw NSError(domain: "TonTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Swap ID must be 32 bytes long"])
      }
      bytes += swapPayload.swapId
      try builder.store(data: swapPayload.swapId)
      
      payload = try builder.endCell()
      hints += putUint16(bytes.count) + bytes
      
      // Tonstakers Deposit
    case .tonstakersDeposit(let depositPayload):
      hints = putUint8(1) + putUint32(0x07)
      let builder = try Builder().store(uint: 0x47d54391, bits: 32)
      var bytes = [UInt8]()
      
      if let queryId = depositPayload.queryId {
        bytes += putUint8(1) + (try putUint64(queryId))
        try builder.store(uint: queryId, bits: 64)
      } else {
        bytes += putUint8(0)
        try builder.store(uint: 0, bits: 64)
      }
      
      if let appId = depositPayload.appId {
        bytes += putUint8(1) + (try putUint64(appId))
        try builder.store(uint: appId, bits: 64)
      } else {
        bytes += putUint8(0)
      }
      
      payload = try builder.endCell()
      hints += putUint16(bytes.count) + bytes
      
      // Vote for Proposal
    case .voteForProposal(let votePayload):
      hints = putUint8(1) + putUint32(0x08)
      let builder = try Builder().store(uint: 0x69fb306c, bits: 32)
      var bytes = [UInt8]()
      
      if let queryId = votePayload.queryId {
        bytes += putUint8(1) + (try putUint64(queryId))
        try builder.store(uint: queryId, bits: 64)
      } else {
        bytes += putUint8(0)
        try builder.store(uint: 0, bits: 64)
      }
      
      bytes += putAddress(votePayload.votingAddress) + (try putUint48(votePayload.expirationDate)) + putUint8(votePayload.vote ? 1 : 0) + putUint8(votePayload.needConfirmation ? 1 : 0)
      try votePayload.votingAddress.storeTo(builder: builder)
      try builder.store(uint: votePayload.expirationDate, bits: 48)
      try builder.store(bit: votePayload.vote)
      try builder.store(bit: votePayload.needConfirmation)
      
      payload = try builder.endCell()
      hints += putUint16(bytes.count) + bytes
      
    case .unsafe(let unsafePayload):
      payload = unsafePayload
      
    case .none: break
    }
    
    if let payload {
      pkg += putUint8(1) + putUint16(Int(payload.depth())) + payload.hash().toByteArray() + hints
    } else {
      pkg += putUint8(0) + putUint8(0)
    }
    
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
      .store(uint: transaction.timeout, bits: 32)
      .store(uint: transaction.seqno, bits: 32)
      .store(uint: 0, bits: 8)
      .store(uint: transaction.sendMode.rawValue, bits: 8)
      .store(ref: orderBuilder.endCell())
    
    return LedgerTransfer(signingMessage: transfer, package: Data(pkg))
  }
  
  public func signAddressProof(path: AccountPath, domain: String, timestamp: UInt64, payload: String) async throws -> Data {
    let publicKey = try await getAccount(path: path).publicKey
    
    let domainData = domain.data(using: .utf8)!
    let timestampData = Data(try TonTransport.putUint64(BigUInt(timestamp)))
    let payloadData = payload.data(using: .utf8)!
    
    let pkg: Data = path.data + Data(TonTransport.putUint8(UInt8(domainData.count))) + domainData + timestampData + payloadData
    
    let res = try await doRequest(ins: TonTransport.INS_PROOF, p1: 0x01, p2: 0x00, data: pkg)
    let signature = res.subdata(in: 1..<65)
    let hash = res.subdata(in: (2 + 64)..<(2 + 64 + 32))
    
    let isValidSignature = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey.data).isValidSignature(signature, for: hash)
    
    if !isValidSignature {
      throw NSError(domain: "TonTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Received signature is invalid"])
    }
    
    return signature
  }
  
  public func signTransaction(path: AccountPath, transaction: Transaction) async throws -> Data {
    let account = try await getAccount(path: path)
    let publicKey = account.publicKey
    
    let transfer: LedgerTransfer = try TonTransport.buildTransfer(transaction: transaction)
    
    let signingMessage = try transfer.signingMessage.endCell()
    
    _ = try await doRequest(ins: TonTransport.INS_SIGN_TX, p1: 0x00, p2: 0x03, data: path.data)
    let pkgChunks = chunks(buf: transfer.package, n: 255)
    for chunk in pkgChunks.dropLast() {
      _ = try await doRequest(ins: TonTransport.INS_SIGN_TX, p1: 0x00, p2: 0x02, data: Data(chunk))
    }
    let res = try await doRequest(ins: TonTransport.INS_SIGN_TX, p1: 0x00, p2: 0x00, data: Data(pkgChunks.last!))
    
    let signature = res.subdata(in: 1..<65)
    let hash = res.subdata(in: 66..<98)
    
    if !hash.elementsEqual(signingMessage.hash()) {
      throw NSError(domain: "TonTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Hash mismatch. Expected: \(signingMessage.hash().hexString()), got: \(hash.hexString())"])
    }
    
    let isValidSignature = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey.data).isValidSignature(signature, for: hash)
    
    if !isValidSignature {
      throw NSError(domain: "TonTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Received signature is invalid"])
    }
    
    return signature
  }
}

private extension TonTransport {
  static func putUint32(_ value: UInt64) -> [UInt8] {
    let byteArray = withUnsafeBytes(of: value.bigEndian, Array.init)
    return Array(byteArray.suffix(4))
  }
  
  static func putUint16(_ value: Int) -> [UInt8] {
    let byteArray = withUnsafeBytes(of: UInt16(value).bigEndian, Array.init)
    return Array(byteArray.suffix(2))
  }
  
  static func putUint48(_ value: BigUInt) throws -> [UInt8] {
    return try Builder().store(biguint: value, bits: 48).endCell().bits.bitsToPaddedBuffer().toByteArray()
  }
  
  static func putUint64(_ value: BigUInt) throws -> [UInt8] {
    return try Builder().store(biguint: value, bits: 64).endCell().bits.bitsToPaddedBuffer().toByteArray()
  }
  
  static func putVarUInt(_ value: BigUInt) throws -> [UInt8] {
    let sizeBytes = value == 0 ? 0 : Int(ceil(Double(value.bitWidth) / 8.0))
    let cell = try Builder().store(uint: sizeBytes, bits: 8).store(uint: value, bits: sizeBytes * 8).endCell()
    return try cell.beginParse().loadBits(8 + sizeBytes * 8).bitsToPaddedBuffer().toByteArray()
  }
  
  static func putUint8(_ value: UInt8) -> [UInt8] {
    return [value]
  }
  
  static func putAddress(_ address: Address) -> [UInt8] {
    let workchainIdByte = address.workchain == -1 ? UInt8(0xff) : UInt8(address.workchain)
    return putUint8(workchainIdByte) + address.hash.toByteArray()
  }
  
  static func putCellRef(_ ref: Cell) -> [UInt8] {
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
