import Foundation
import TonSwift
import Sodium

enum SignDataError: Error {
    case wrongPayloadType
    case invalidDataEncoding
    case signatureFailure
    case addressFailure
}

public struct SignedDataResult: Encodable {
  public let signature: String
  public let timestamp: UInt64
  public let address: String
  public let domain: String
  public let payload: TonConnectSignDataPayload
}

public protocol SignDataSignerByPayloadType {
  init(_ signDataPayload: TonConnect.SignDataRequest, wallet: Wallet, mnemonicsRepository: MnemonicsRepository, dappUrl: String, passcode: String)
  func sign() async throws -> SignedDataResult
}

public struct TextOrBinSignDataSigner: SignDataSignerByPayloadType {
  let wallet: Wallet
  let dappUrl: String
  let signDataPayload: TonConnect.SignDataRequest
  let mnemonicsRepository: MnemonicsRepository
  let passcode: String
  
  public init(_ signDataPayload: TonConnect.SignDataRequest, wallet: Wallet, mnemonicsRepository: MnemonicsRepository, dappUrl: String, passcode: String)  {
    self.signDataPayload = signDataPayload
    self.wallet = wallet
    self.mnemonicsRepository = mnemonicsRepository
    self.dappUrl = dappUrl
    self.passcode = passcode
  }
  
  public func sign() async throws -> SignedDataResult {
    guard let prefix = "ton-connect/sign-data/".data(using: .utf8) else {
        throw SignDataError.invalidDataEncoding
    }
    
    guard let payloadPrefix: Data = {
      switch signDataPayload.params {
      case .text:
        return "txt".data(using: .utf8)
      case .binary:
        return "bin".data(using: .utf8)
      default:
        return nil
      }
    }() else {
        throw SignDataError.invalidDataEncoding
    }
    
    let address = try wallet.address
    
    let addressWorkchain = UInt32(bigEndian: UInt32(address.workchain))
    let addressWorkchainData = withUnsafeBytes(of: addressWorkchain) { a in
      Data(a)
    }
    let addressHash = address.hash
    
    let timestampUint64 = UInt64(Date().timeIntervalSince1970)
    let timestamp = withUnsafeBytes(of: UInt64(bigEndian: timestampUint64)) { a in
      Data(a)
    }
    
    guard let domainData = dappUrl.data(using: .utf8) else {
        throw SignDataError.invalidDataEncoding
    }
    
    let domainLength = withUnsafeBytes(of: UInt32(bigEndian: UInt32(domainData.count))) { a in
      Data(a)
    }
    
    let payload: Data = try {
      switch signDataPayload.params {
      case .text(let text):
        guard let textData = text.data(using: .utf8) else {
            throw SignDataError.invalidDataEncoding
        }
        return textData
      case .binary(let data):
        guard let binaryData = Data(base64Encoded: data) else {
            throw SignDataError.invalidDataEncoding
        }
        return binaryData
      default:
        throw SignDataError.wrongPayloadType
      }
    }()
    
    let payloadLength = UInt32(bigEndian: UInt32(payload.count))
    let payloadLengthData = withUnsafeBytes(of: payloadLength) { a in
      Data(a)
    }
    
    guard let ffff = Data(hex: "ffff") else {
        throw SignDataError.invalidDataEncoding
    }
    
    let message = ffff + prefix + addressWorkchainData + addressHash + domainLength + domainData + timestamp + payloadPrefix + payloadLengthData + payload
        
    let signatureDataHash = message.sha256()
    
    let mnemonic = try await mnemonicsRepository.getMnemonic(
      wallet: wallet,
      password: passcode
    )
    let keyPair = try TonSwift.Mnemonic.anyMnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
    
    let sodium = Sodium()
    guard let signature = sodium.sign.signature(
      message: signatureDataHash.bytes,
      secretKey: keyPair.privateKey.data.bytes
    ) else {
        throw SignDataError.signatureFailure
    }
    
    return .init(
      signature: Data(signature).base64EncodedString(),
      timestamp: timestampUint64,
      address: address.toRaw(),
      domain: dappUrl,
      payload: signDataPayload.params
    )
  }
}

public struct CellSignDataSigner: SignDataSignerByPayloadType {
  let wallet: Wallet
  let mnemonicsRepository: MnemonicsRepository
  let dappUrl: String
  let signDataPayload: TonConnect.SignDataRequest
  let passcode: String
  
  public init(_ signDataPayload: TonConnect.SignDataRequest, wallet: Wallet, mnemonicsRepository: MnemonicsRepository, dappUrl: String, passcode: String) {
    self.signDataPayload = signDataPayload
    self.wallet = wallet
    self.mnemonicsRepository = mnemonicsRepository
    self.dappUrl = dappUrl
    self.passcode = passcode
  }
  
  public func sign() async throws -> SignedDataResult {
    let address = try wallet.address
    let builder = Builder()
    try builder.store(uint: 0x75569022, bits: 32)
    
    let payload: (schema: Data, cell: String) = try {
      switch signDataPayload.params {
      case .cell(let schema, let cell):
        guard let schemaData = schema.data(using: .utf8)?.crc32() else {
            throw SignDataError.invalidDataEncoding
        }
        return (schema: schemaData, cell: cell)
      default:
        throw SignDataError.wrongPayloadType
      }
    }()
    
    try builder.store(data: payload.schema)
    
    let timestamp = UInt64(Date().timeIntervalSince1970)
    
    try builder.store(uint: timestamp, bits: 64)
    try builder.store(address)
    try builder.store(ref: Builder().store(data: dappUrl.data(using: .utf8)!))
    
    try builder.store(ref: try Cell.fromBase64(src: payload.cell))
    
    let mnemonic = try await mnemonicsRepository.getMnemonic(
      wallet: wallet,
      password: passcode
    )
    let keyPair = try TonSwift.Mnemonic.anyMnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
    
    let sodium = Sodium()
    guard let signature = sodium.sign.signature(
      message: try builder.endCell().hash().bytes,
      secretKey: keyPair.privateKey.data.bytes
    ) else {
        throw SignDataError.signatureFailure
    }
    
    return .init(
      signature: Data(signature).base64EncodedString(),
      timestamp: timestamp,
      address: address.toRaw(),
      domain: dappUrl,
      payload: signDataPayload.params
    )
  }
}

public struct SignDataSigner {
  let signerByPayloadType: SignDataSignerByPayloadType
  
  public init(_ signDataPayload: TonConnect.SignDataRequest, wallet: Wallet, mnemonicsRepository: MnemonicsRepository, dappUrl: String, passcode: String) throws {
    signerByPayloadType = {
      switch signDataPayload.params {
      case .text(_), .binary(_):
        return TextOrBinSignDataSigner(signDataPayload, wallet: wallet, mnemonicsRepository: mnemonicsRepository, dappUrl: dappUrl, passcode: passcode)
      case .cell(_, _):
        return CellSignDataSigner(signDataPayload, wallet: wallet, mnemonicsRepository: mnemonicsRepository, dappUrl: dappUrl, passcode: passcode)
      }
    }()
  }

  
  
  public func sign() async throws -> SignedDataResult {
    return try await signerByPayloadType.sign()
  }
}
