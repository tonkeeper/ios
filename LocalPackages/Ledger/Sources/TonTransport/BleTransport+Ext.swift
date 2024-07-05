import Foundation
import BleTransport
import TonSwift

public extension BleTransportProtocol {
  func send(system: UInt8, command: UInt8, p1: UInt8, p2: UInt8, data: Data = Data(), responseCodes: [TransportStatusCodes]? = nil) async throws -> Data {
    var buffer = Data()
    buffer.append(system)
    buffer.append(command)
    buffer.append(p1)
    buffer.append(p2)
    buffer.append(UInt8(data.count))
    buffer.append(data)
    
    let apdu = try APDU(bluetoothData: buffer)
    
    let response = try await exchange(apdu: apdu)
    let responseData = Data(hex: response)!
    
    let sw = readUInt16BE(response: responseData, offset: responseData.count - 2)
    
    let effectiveResponseCodes = responseCodes?.map { $0.rawValue } ?? [TransportStatusCodes.ok.rawValue]
    
    if !effectiveResponseCodes.contains(sw) {
      throw TransportStatusError.fromStatusCode(sw)
    }
    
    return responseData
  }
  
  private func readUInt16BE(response: Data, offset: Int) -> UInt16 {
    let range = offset..<(offset + 2)
    return response.subdata(in: range).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
  }
}

public enum TransportStatusCodes: UInt16 {
  case accessConditionNotFulfilled = 0x9804
  case algorithmNotSupported = 0x9484
  case claNotSupported = 0x6e00
  case codeBlocked = 0x9840
  case codeNotInitialized = 0x9802
  case commandIncompatibleFileStructure = 0x6981
  case conditionsOfUseNotSatisfied = 0x6985
  case contradictionInvalidation = 0x9810
  case contradictionSecretCodeStatus = 0x9808
  case customImageBootloader = 0x662f
  case customImageEmpty = 0x662e
  case fileAlreadyExists = 0x6a89
  case fileNotFound = 0x9404
  case gpAuthFailed = 0x6300
  case halted = 0x6faa
  case inconsistentFile = 0x9408
  case incorrectData = 0x6a80
  case incorrectLength = 0x6700
  case incorrectP1P2 = 0x6b00
  case insNotSupported = 0x6d00
  case deviceNotOnboarded = 0x6d07
  case deviceNotOnboarded2 = 0x6611
  case invalidKcv = 0x9485
  case invalidOffset = 0x9402
  case licensing = 0x6f42
  case lockedDevice = 0x5515
  case maxValueReached = 0x9850
  case memoryProblem = 0x9240
  case missingCriticalParameter = 0x6800
  case noEfSelected = 0x9400
  case notEnoughMemorySpace = 0x6a84
  case ok = 0x9000
  case pinRemainingAttempts = 0x63c0
  case referencedDataNotFound = 0x6a88
  case securityStatusNotSatisfied = 0x6982
  case technicalProblem = 0x6f00
  case unknownApdu = 0x6d02
  case userRefusedOnDevice = 0x5501
  case notEnoughSpace = 0x5102
}

extension BleTransportError: Equatable {
    public static func == (lhs: BleTransportError, rhs: BleTransportError) -> Bool {
        switch (lhs, rhs) {
        case (.pendingActionOnDevice, .pendingActionOnDevice),
             (.userRefusedOnDevice, .userRefusedOnDevice),
             (.scanningTimedOut, .scanningTimedOut),
             (.bluetoothNotAvailable, .bluetoothNotAvailable):
            return true
        case let (.connectError(desc1), .connectError(desc2)),
             let (.currentConnectedError(desc1), .currentConnectedError(desc2)),
             let (.writeError(desc1), .writeError(desc2)),
             let (.readError(desc1), .readError(desc2)),
             let (.listenError(desc1), .listenError(desc2)),
             let (.scanError(desc1), .scanError(desc2)),
             let (.pairingError(desc1), .pairingError(desc2)),
             let (.lowerLevelError(desc1), .lowerLevelError(desc2)):
            return desc1 == desc2
        default:
            return false
        }
    }
}
