import Foundation
import TonSwift

@frozen public enum TonConnect {
    /// `0xffff` — the fixed prefix every TON Connect signature payload starts with.
    static let signaturePrefix = Data([0xFF, 0xFF])
}

public extension TonConnect {
    struct DeviceInfo: Encodable {
        public let platform = "iphone"
        public let appName = "Tonkeeper"
        public let maxProtocolVersion = 2
        public let features: [FeatureCompatible]
        public let appVersion: String

        @frozen public enum FeatureCompatible: Encodable {
            case feature(Feature)
            case legacy(Feature)

            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case let .feature(feature):
                    try container.encode(feature)
                case let .legacy(feature):
                    try container.encode(feature.name)
                }
            }
        }

        @frozen public enum SignDataType: String, Encodable {
            case text
            case binary
            case cell
        }

        @frozen public enum Feature: Encodable {
            case sendTransaction(maxMessages: Int)
            case signData(types: [SignDataType])
            case signMessage(maxMessages: Int)

            var name: String {
                switch self {
                case .sendTransaction:
                    return "SendTransaction"
                case .signData:
                    return "SignData"
                case .signMessage:
                    return "SignMessage"
                }
            }

            private enum CodingKeys: String, CodingKey {
                case name
                case maxMessages
                case types
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case let .sendTransaction(maxMessages):
                    try container.encode(name, forKey: .name)
                    try container.encode(maxMessages, forKey: .maxMessages)
                case let .signData(types):
                    try container.encode(name, forKey: .name)
                    try container.encode(types, forKey: .types)
                case let .signMessage(maxMessages):
                    try container.encode(name, forKey: .name)
                    try container.encode(maxMessages, forKey: .maxMessages)
                }
            }
        }

        public init(maxMessages: Int, appVersion: String, isSignMessageSupported: Bool) {
            self.appVersion = appVersion
            var features = [
                FeatureCompatible.legacy(.sendTransaction(maxMessages: maxMessages)),
                FeatureCompatible.feature(.sendTransaction(maxMessages: maxMessages)),
                FeatureCompatible.feature(.signData(types: [.text, .binary, .cell])),
            ]
            if isSignMessageSupported {
                features.append(.feature(.signMessage(maxMessages: maxMessages)))
            }
            self.features = features
        }
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

        @frozen public enum Error: Int, Encodable, Swift.Error {
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

    @frozen enum ConnectItemReply: Encodable {
        case tonAddress(TonAddressItemReply)
        case tonProof(TonProofItemReply)
        case tonProofSigned(TonProofItemReplySigned)
    }

    struct TonAddressItemReply: Encodable {
        public let name = "ton_addr"
        public let address: TonSwift.Address
        public let network: Network
        public let publicKey: TonSwift.PublicKey
        public let walletStateInit: TonSwift.StateInit
    }

    @frozen enum TonProofItemReplySigned: Encodable {
        case success(TonProofItemReplySignedSuccess)
        case error(TonProofItemReplySignedError)
    }

    struct TonProofItemReplySignedSuccess: Encodable {
        public struct Proof: Encodable {
            public let timestamp: UInt64
            public let domain: Domain
            public let signature: Data
            public let payload: String
        }

        public let name = "ton_proof"
        public let proof: Proof
    }

    struct TonProofItemReplySignedError: Encodable {
        public struct Error: Encodable {
            let message: String?
            let code: ErrorCode
        }

        @frozen public enum ErrorCode: Int, Encodable {
            case unknownError = 0
            case methodNotSupported = 400
        }

        public let name = "ton_proof"
        public let error: Error
    }

    @frozen enum TonProofItemReply: Encodable {
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

        public let name = "ton_proof"
        public let proof: Proof
    }

    struct TonProofItemReplyError: Encodable {
        public struct Error: Encodable {
            let message: String?
            let code: ErrorCode
        }

        @frozen public enum ErrorCode: Int, Encodable {
            case unknownError = 0
            case methodNotSupported = 400
        }

        public let name = "ton_proof"
        public let error: Error
    }

    struct TonProof: Encodable {
        public let timestamp: UInt64
        public let domain: Domain
        public let signature: Signature
        public let payload: String

        public init(
            timestamp: UInt64,
            domain: Domain,
            signature: Signature,
            payload: String
        ) {
            self.timestamp = timestamp
            self.domain = domain
            self.signature = signature
            self.payload = payload
        }
    }

    struct SignatureData: Encodable {
        public let address: TonSwift.Address
        public let domain: Domain
        public let timestamp: UInt64
        public let payload: String

        public init(
            address: TonSwift.Address,
            domain: Domain,
            timestamp: UInt64,
            payload: String
        ) {
            self.address = address
            self.domain = domain
            self.timestamp = timestamp
            self.payload = payload
        }
    }

    struct Signature: Encodable {
        public let signatureData: SignatureData
        public let privateKey: PrivateKey

        public init(
            signatureData: SignatureData,
            privateKey: PrivateKey
        ) {
            self.signatureData = signatureData
            self.privateKey = privateKey
        }
    }

    struct Domain: Encodable {
        public let value: String
        public let lengthBytes: UInt32
    }
}

public extension TonConnect.Domain {
    init(domain: String) {
        let domainLength = UInt32(domain.utf8.count)
        self.value = domain
        self.lengthBytes = domainLength
    }
}

public extension TonConnect.TonProofItemReplySuccess {
    init(
        address: TonSwift.Address,
        domain: String,
        payload: String,
        privateKey: PrivateKey
    ) {
        let timestamp = UInt64(Date().timeIntervalSince1970)
        let domain = TonConnect.Domain(domain: domain)
        let signature = TonConnect.Signature(
            signatureData: .init(
                address: address,
                domain: domain,
                timestamp: timestamp,
                payload: payload
            ),
            privateKey: privateKey
        )
        let proof = Proof(
            timestamp: timestamp,
            domain: domain,
            signature: signature,
            payload: payload,
            privateKey: privateKey
        )

        self.init(proof: proof)
    }
}

public extension TonConnect.TonProofItemReplySignedSuccess {
    init(
        data: TonConnect.SignatureData,
        signature: Data
    ) {
        let proof = Proof(
            timestamp: data.timestamp,
            domain: data.domain,
            signature: signature,
            payload: data.payload
        )
        self.init(proof: proof)
    }
}

public extension TonConnect {
    @frozen enum SendResponse {
        case success(SendResponseSuccess)
        case error(SendResponseError)
    }

    struct SignMessageResult: Encodable {
        public let internalBoc: String

        public init(internalBoc: String) {
            self.internalBoc = internalBoc
        }
    }

    struct SendResponseSuccess: Encodable {
        @frozen public enum Result: Encodable {
            case String(String)
            case SignedData(SignedDataResult)
            case SignedMessage(SignMessageResult)
            case empty

            private struct EmptyObject: Encodable {}

            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()

                switch self {
                case let .String(a0):
                    try container.encode(a0)
                case let .SignedData(a0):
                    try container.encode(a0)
                case let .SignedMessage(a0):
                    try container.encode(a0)
                case .empty:
                    try container.encode(EmptyObject())
                }
            }
        }

        public let result: Result
        public let id: String

        public init(result: String, id: String) {
            self.result = .String(result)
            self.id = id
        }

        public init(result: SignedDataResult, id: String) {
            self.result = .SignedData(result)
            self.id = id
        }

        public init(result: SignMessageResult, id: String) {
            self.result = .SignedMessage(result)
            self.id = id
        }

        public init(id: String) {
            result = .empty
            self.id = id
        }
    }

    struct FetchEventError: Encodable {
        public let code: ErrorCode
        public let message: String

        @frozen public enum ErrorCode: Int, Encodable {
            case unknownError = 0
        }
    }

    struct SendResponseError: Encodable {
        public struct Error: Encodable {
            public let code: ErrorCode
            public let message: String

            public init(code: ErrorCode, message: String) {
                self.code = code
                self.message = message
            }
        }

        @frozen public enum ErrorCode: Int, Encodable, Swift.Error {
            case unknownError = 0
            case badRequest = 1
            case unknownApp = 10
            case userDeclinedAction = 300
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
