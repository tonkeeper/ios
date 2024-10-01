import Foundation
import TonSwift

public enum TonConnect {}

public extension TonConnect {
  enum ConnectEvent: Encodable {
    case success(ConnectEventSuccess)
    case error(ConnectEventError)
  }
  struct DeviceInfo: Encodable {
    public let platform = "iphone"
    public let appName = "Tonkeeper"
    public let appVersion = "3.4.0"
    public let maxProtocolVersion = 2
    public let features = [
      FeatureCompatible.legacy(Feature()),
      FeatureCompatible.feature(Feature())
    ]
    
    public enum FeatureCompatible: Encodable {
      case feature(Feature)
      case legacy(Feature)
            
      public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
          case .feature(let feature):
            try container.encode(feature)
          case .legacy(let feature):
            try container.encode(feature.name)
        }
      }
    }
    
    public struct Feature: Encodable {
      public let name = "SendTransaction"
      public let maxMessages = 4
    }
    
    public init() {}
  }
  struct ConnectEventSuccess: Encodable {
    public struct Payload: Encodable {
      public let items: [ConnectItemReply]
      public let device: DeviceInfo
    }
    public let event = "connect"
    public let id = Int(Date().timeIntervalSince1970)
    public let payload: Payload
  }
  struct ConnectEventError: Encodable {
    public struct Payload: Encodable {
      public let code: Error
      public let message: String
    }
    public enum Error: Int, Encodable, Swift.Error {
      case unknownError = 0
      case badRequest = 1
      case appManifestNotFound = 2
      case appManifestContentError = 3
      case unknownApp = 100
      case userDeclinedTheConnection = 300
    }
    public let event = "connect_error"
    public let id = Int(Date().timeIntervalSince1970)
    public let payload: Payload
  }
  
  enum ConnectItemReply: Encodable {
    case tonAddress(TonAddressItemReply)
    case tonProof(TonProofItemReply)
  }
  struct TonAddressItemReply: Encodable {
    public let name = "ton_addr"
    public let address: TonSwift.Address
    public let network: Network
    public let publicKey: TonSwift.PublicKey
    public let walletStateInit: TonSwift.StateInit
  }
  enum TonProofItemReply: Encodable {
    case success(TonProofItemReplySuccess)
    case error(TonProofItemReplyError)
  }
  struct TonProofItemReplySuccess: Encodable {
    public struct Proof: Encodable {
      public let timestamp: UInt64
      public let domain: Domain
      public let signature: Signature
      public let payload: String
      public let privateKey: PrivateKey
    }
    
    public struct Signature: Encodable {
      public let address: TonSwift.Address
      public let domain: Domain
      public let timestamp: UInt64
      public let payload: String
    }
    
    public struct Domain: Encodable {
      public let lengthBytes: UInt32
      public let value: String
    }
    
    public let name = "ton_proof"
    public let proof: Proof
  }
  
  struct TonProofItemReplyError: Encodable {
    public struct Error: Encodable {
      let message: String?
      let code: ErrorCode
    }
    public enum ErrorCode: Int, Encodable {
      case unknownError = 0
      case methodNotSupported = 400
    }
    
    public let name = "ton_proof"
    public let error: Error
  }
}

extension TonConnect.TonProofItemReplySuccess {

  public init(address: TonSwift.Address,
       domain: String,
       payload: String,
       privateKey: PrivateKey) {
    let timestamp = UInt64(Date().timeIntervalSince1970)
    let domain = Domain(domain: domain)
    let signature = Signature(
      address: address,
      domain: domain,
      timestamp: timestamp,
      payload: payload)
    let proof = Proof(
      timestamp: timestamp,
      domain: domain,
      signature: signature,
      payload: payload,
      privateKey: privateKey)
    
    self.init(proof: proof)
  }
}


public extension TonConnect.TonProofItemReplySuccess.Domain {
  init(domain: String) {
    let domainLength = UInt32(domain.utf8.count)
    self.value = domain
    self.lengthBytes = domainLength
  }
}

public extension TonConnect {
  enum SendTransactionResponse {
    case success(SendTransactionResponseSuccess)
    case error(SendTransactionResponseError)
  }
  struct SendTransactionResponseSuccess: Encodable {
    public let result: String
    public let id: String
    
    public init(result: String, id: String) {
      self.result = result
      self.id = id
    }
  }
  struct SendTransactionResponseError: Encodable {
    public struct Error: Encodable {
      public let code: ErrorCode
      public let message: String
      
      public init(code: ErrorCode, message: String) {
        self.code = code
        self.message = message
      }
    }
    
    public enum ErrorCode: Int, Encodable, Swift.Error {
      case unknownError = 0
      case badRequest = 1
      case unknownApp = 10
      case userDeclinedTransaction = 300
      case methodNotSupported = 400
    }
    
    public let id: String
    public let error: Error
    
    public init(id: String, error: Error) {
      self.id = id
      self.error = error
    }
  }
}
