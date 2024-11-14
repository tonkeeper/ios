import Foundation
import TonSwift
import BigInt

public enum TonPayloadFormat {
  case comment(String)
  case jettonTransfer(JettonTransfer)
  case nftTransfer(NftTransfer)
  case jettonBurn(JettonBurn)
  case singleNominatorWithdraw(SingleNominatorWithdraw)
  case singleNominatorChangeValidator(SingleNominatorChangeValidator)
  case addWhitelist(AddWhitelist)
  case tonstakersDeposit(TonstakersDeposit)
  case voteForProposal(VoteForProposal)
  case changeDNSRecord(ChangeDNSRecord)
  case tokenBridgePaySwap(TokenBridgePaySwap)
  case unsafe(Cell)
  
  public enum PayloadType: String, Codable {
    case comment
    case jettonTransfer
    case nftTransfer
    case jettonBurn
    case singleNominatorWithdraw
    case singleNominatorChangeValidator
    case addWhitelist
    case tonstakersDeposit
    case voteForProposal
    case changeDNSRecord
    case tokenBridgePaySwap
    case unsafe
  }
  
  public struct JettonTransfer {
    let queryId: BigUInt?
    let coins: Coins
    let receiverAddress: Address
    let excessesAddress: Address
    let customPayload: Cell?
    let forwardAmount: Coins
    let forwardPayload: Cell?
    
    public init(queryId: BigUInt?, coins: Coins, receiverAddress: Address, excessesAddress: Address, customPayload: Cell?, forwardAmount: Coins, forwardPayload: Cell?) {
      self.queryId = queryId
      self.coins = coins
      self.receiverAddress = receiverAddress
      self.excessesAddress = excessesAddress
      self.customPayload = customPayload
      self.forwardAmount = forwardAmount
      self.forwardPayload = forwardPayload
    }
  }
  
  public struct NftTransfer {
    let queryId: BigUInt?
    let newOwnerAddress: Address
    let excessesAddress: Address
    let customPayload: Cell?
    let forwardAmount: Coins
    let forwardPayload: Cell?
    
    public init(queryId: BigUInt?, newOwnerAddress: Address, excessesAddress: Address, customPayload: Cell?, forwardAmount: Coins, forwardPayload: Cell?) {
      self.queryId = queryId
      self.newOwnerAddress = newOwnerAddress
      self.excessesAddress = excessesAddress
      self.customPayload = customPayload
      self.forwardAmount = forwardAmount
      self.forwardPayload = forwardPayload
    }
  }
  
  public struct JettonBurn {
    let queryId: BigUInt?
    let coins: Coins
    let responseDestination: Address
    let customPayload: JettonBurnCustomPayload?
  }
  
  public struct SingleNominatorWithdraw {
    let queryId: BigUInt?
    let coins: Coins
  }
  
  public struct SingleNominatorChangeValidator {
    let queryId: BigUInt?
    let address: Address
  }
  
  public struct AddWhitelist {
    let queryId: BigUInt?
    let address: Address
  }
  
  public struct TonstakersDeposit {
    let queryId: BigUInt?
    let appId: BigUInt?
  }
  
  public struct VoteForProposal {
    let queryId: BigUInt?
    let votingAddress: Address
    let expirationDate: BigUInt
    let vote: Bool
    let needConfirmation: Bool
  }
  
  public struct ChangeDNSRecord {
    let queryId: BigUInt?
    let record: DNSRecord
  }
  
  public struct TokenBridgePaySwap {
    let queryId: BigUInt?
    let swapId: Data
  }
  
  // Definitions for DNSRecord and JettonBurnCustomPayload
  public enum DNSRecord {
    case wallet(DNSWalletRecord?)
    case unknown(key: Data, value: Cell?)
  }
  
  public struct DNSWalletRecord {
    let address: Address
    let capabilities: DnsChangeCapabilities?
  }
  
  public struct DnsChangeCapabilities {
    var isWallet: Bool
  }
  
  public enum JettonBurnCustomPayload {
    case cellPayload(Cell)
    case byteArrayPayload(Data)
    
    public static func checkAndConvertPayload(_ customPayload: inout JettonBurnCustomPayload?) throws {
      if let payload = customPayload,
         case .cellPayload(let cell) = payload,
         cell.bits.length == 20,
         cell.refs.isEmpty {
        
        let slice = try cell.beginParse()
        if let byteArray = try? slice.loadBytes(20) {
          customPayload = .byteArrayPayload(byteArray)
        }
        try slice.endParse()
      }
    }
  }
  
  // Static method to parse a Cell and create a TonPayloadFormat
  public static func from(cell: Cell) throws -> TonPayloadFormat {
    let slice = try cell.beginParse()
    
    do {
      let op = try slice.loadUint(bits: 32)
      switch op {
      case 0:
        let str = try slice.loadSnakeString()
        try slice.endParse()
        guard str.count <= 120 else {
          throw NSError(domain: "TonTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Comment must be at most 120 ASCII characters long"])
        }
        for char in str where char < "\u{20}" || char >= "\u{7f}" {
          throw NSError(domain: "TonTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Comment must only contain printable ASCII characters"])
        }
        return .comment(str)
        
      case 0x0f8a7ea5:
        let queryId = normalizeQueryId(try slice.loadUint(bits: 64))
        let coins: Coins = try slice.loadType()
        let receiverAddress: Address = try slice.loadType()
        let excessesAddress: Address = try slice.loadType()
        let customPayload = try slice.loadBoolean() ? try slice.loadRef() : nil
        let forwardAmount: Coins = try slice.loadType()
        let forwardPayload = try slice.loadBoolean() ? try slice.loadRef() : nil
        try slice.endParse()
        
        return .jettonTransfer(JettonTransfer(
          queryId: queryId,
          coins: coins,
          receiverAddress: receiverAddress,
          excessesAddress: excessesAddress,
          customPayload: customPayload,
          forwardAmount: forwardAmount,
          forwardPayload: forwardPayload
        ))
        
      case 0x5fcc3d14:
        let queryId = normalizeQueryId(try slice.loadUint(bits: 64))
        let newOwnerAddress: Address = try slice.loadType()
        let excessesAddress: Address = try slice.loadType()
        let customPayload = try slice.loadBoolean() ? try slice.loadRef() : nil
        let forwardAmount: Coins = try slice.loadType()
        let forwardPayload = try slice.loadBoolean() ? try slice.loadRef() : nil
        try slice.endParse()
        
        return .nftTransfer(NftTransfer(
          queryId: queryId,
          newOwnerAddress: newOwnerAddress,
          excessesAddress: excessesAddress,
          customPayload: customPayload,
          forwardAmount: forwardAmount,
          forwardPayload: forwardPayload
        ))
        
      case 0x595f07bc:
        let queryId = normalizeQueryId(try slice.loadUint(bits: 64))
        let coins: Coins = try slice.loadType()
        let responseDestination: Address = try slice.loadType()
        var customPayload: JettonBurnCustomPayload? = try slice.loadBoolean() ? .cellPayload(try slice.loadRef()) : nil
        try slice.endParse()
        
        try JettonBurnCustomPayload.checkAndConvertPayload(&customPayload)
        
        return .jettonBurn(JettonBurn(
          queryId: queryId,
          coins: coins,
          responseDestination: responseDestination,
          customPayload: customPayload
        ))
        
      case 0x7258a69b:
        let queryId = normalizeQueryId(try slice.loadUint(bits: 64))
        let address: Address = try slice.loadType()
        try slice.endParse()
        
        return .addWhitelist(AddWhitelist(
          queryId: queryId,
          address: address
        ))
        
      case 0x1000:
        let queryId = normalizeQueryId(try slice.loadUint(bits: 64))
        let coins: Coins = try slice.loadType()
        try slice.endParse()
        
        return .singleNominatorWithdraw(SingleNominatorWithdraw(
          queryId: queryId,
          coins: coins
        ))
        
      case 0x1001:
        let queryId = normalizeQueryId(try slice.loadUint(bits: 64))
        let address: Address = try slice.loadType()
        try slice.endParse()
        
        return .singleNominatorChangeValidator(SingleNominatorChangeValidator(
          queryId: queryId,
          address: address
        ))
        
      case 0x47d54391:
        let queryId = normalizeQueryId(try slice.loadUint(bits: 64))
        let appId = slice.remainingBits > 0 ? BigUInt(try slice.loadUint(bits: 64)) : nil
        try slice.endParse()
        
        return .tonstakersDeposit(TonstakersDeposit(
          queryId: queryId,
          appId: appId
        ))
        
      case 0x69fb306c:
        let queryId = normalizeQueryId(try slice.loadUint(bits: 64))
        let votingAddress: Address = try slice.loadType()
        let expirationDate = BigUInt(try slice.loadUint(bits: 48))
        let vote = try slice.loadBoolean()
        let needConfirmation = try slice.loadBoolean()
        try slice.endParse()
        
        return .voteForProposal(VoteForProposal(
          queryId: queryId,
          votingAddress: votingAddress,
          expirationDate: expirationDate,
          vote: vote,
          needConfirmation: needConfirmation
        ))
        
      case 0x4eb1f0f9:
        let queryId = normalizeQueryId(try slice.loadUint(bits: 64))
        let key = try slice.loadBytes(32)
        
        if key == dnsWalletKey {
          if slice.remainingRefs > 0 {
            let vs = try slice.loadRef().beginParse()
            
            if !(try slice.loadBoolean()) {
              throw NSError(domain: "TonTransport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Incorrect change DNS record message"])
            }
            
            try slice.endParse()
            
            let type = try vs.loadUint(bits: 16)
            guard type == 0x9fd3 else {
              throw NSError(domain: "TonTransport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Wrong DNS record type"])
            }
            
            let address: Address = try vs.loadType()
            let flags = try vs.loadUint(bits: 8)
            
            guard flags <= 1 else {
              throw NSError(domain: "TonTransport", code: 2, userInfo: [NSLocalizedDescriptionKey: "DNS wallet record must have flags 0 or 1"])
            }
            
            var capabilities: DnsChangeCapabilities? = nil
            if flags & 1 > 0 {
              capabilities = DnsChangeCapabilities(isWallet: false)
            }
            
            if var caps = capabilities {
              while try vs.loadBoolean() {
                let cap = try vs.loadUint(bits: 16)
                if cap == 0x2177 {
                  caps.isWallet = true
                } else {
                  throw NSError(domain: "TonTransport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown DNS wallet record capability"])
                }
              }
            }
            
            return .changeDNSRecord(ChangeDNSRecord(
              queryId: queryId,
              record: .wallet(DNSWalletRecord(
                address: address,
                capabilities: capabilities
              ))
            ))
          } else {
            if slice.remainingBits > 0 {
              if try slice.loadBoolean() {
                throw NSError(domain: "TonTransport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Incorrect change DNS record message"])
              }
            }
            
            try slice.endParse()
            
            return .changeDNSRecord(ChangeDNSRecord(
              queryId: queryId,
              record: .wallet(nil)
            ))
          }
        } else {
          if slice.remainingRefs > 0 {
            let value = try slice.loadRef()
            
            if slice.remainingBits > 0 {
              if !(try slice.loadBoolean()) {
                throw NSError(domain: "TonTransport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Incorrect change DNS record message"])
              }
            }
            
            try slice.endParse()
            
            return .changeDNSRecord(ChangeDNSRecord(
              queryId: queryId,
              record: .unknown(key: key, value: value)
            ))
          } else {
            if slice.remainingBits > 0 {
              if try slice.loadBoolean() {
                throw NSError(domain: "TonTransport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Incorrect change DNS record message"])
              }
            }
            
            try slice.endParse()
            
            return .changeDNSRecord(ChangeDNSRecord(
              queryId: queryId,
              record: .unknown(key: key, value: nil)
            ))
          }
        }
        
      case 0x8:
        let queryId = normalizeQueryId(try slice.loadUint(bits: 64))
        let swapId = try slice.loadBytes(32)
        try slice.endParse()
        
        return .tokenBridgePaySwap(TokenBridgePaySwap(
          queryId: queryId,
          swapId: swapId
        ))
        
      default:
        return .unsafe(cell)
      }
      
    } catch {
      return .unsafe(cell)
    }
  }
}

private extension TonPayloadFormat {
  static let dnsWalletKey: Data = Data([
    0xe8, 0xd4, 0x40, 0x50, 0x87, 0x3d, 0xba, 0x86,
    0x5a, 0xa7, 0xc1, 0x70, 0xab, 0x4c, 0xce, 0x64,
    0xd9, 0x08, 0x39, 0xa3, 0x4d, 0xcf, 0xd6, 0xcf,
    0x71, 0xd1, 0x4e, 0x02, 0x05, 0x44, 0x3b, 0x1b
  ])
  
  static func normalizeQueryId(_ queryId: UInt64) -> BigUInt? {
    return queryId != 0 ? BigUInt(queryId) : nil
  }
}
