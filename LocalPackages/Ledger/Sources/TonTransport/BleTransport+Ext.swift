import BleTransport
import Foundation
import TonSwift

enum BleTransportSendError: Swift.Error {
    case incorrectDataLength(Int)
    case invalidResponse(String)
}

public extension BleTransportProtocol {
    func send(
        system: UInt8,
        command: UInt8,
        p1: UInt8,
        p2: UInt8,
        data: Data = Data(),
        responseCodes: [TransportStatusCodes]? = nil
    ) async throws -> Data {
        guard data.count <= 255 else {
            throw BleTransportSendError.incorrectDataLength(data.count)
        }

        var buffer = Data()
        buffer.append(system)
        buffer.append(command)
        buffer.append(p1)
        buffer.append(p2)
        buffer.append(UInt8(data.count))
        buffer.append(data)

        let apdu = try APDU(bluetoothData: buffer)

        let response = try await exchange(apdu: apdu)

        guard let responseData = Data(hex: response) else {
            throw BleTransportSendError.invalidResponse(response)
        }

        let sw = readUInt16BE(response: responseData, offset: responseData.count - 2)

        let effectiveResponseCodes = responseCodes?.map { $0.rawValue } ?? [TransportStatusCodes.ok.rawValue]

        if !effectiveResponseCodes.contains(sw) {
            throw TransportStatusError.fromStatusCode(sw)
        }

        return responseData
    }

    private func readUInt16BE(response: Data, offset: Int) -> UInt16 {
        let range = offset ..< (offset + 2)
        return response.subdata(in: range).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
    }
}

public enum TransportStatusCodes: UInt16 {
    case accessConditionNotFulfilled = 0x9804
    case algorithmNotSupported = 0x9484
    case claNotSupported = 0x6E00
    case codeBlocked = 0x9840
    case codeNotInitialized = 0x9802
    case commandIncompatibleFileStructure = 0x6981
    case conditionsOfUseNotSatisfied = 0x6985
    case contradictionInvalidation = 0x9810
    case contradictionSecretCodeStatus = 0x9808
    case customImageBootloader = 0x662F
    case customImageEmpty = 0x662E
    case fileAlreadyExists = 0x6A89
    case fileNotFound = 0x9404
    case gpAuthFailed = 0x6300
    case halted = 0x6FAA
    case inconsistentFile = 0x9408
    case incorrectData = 0x6A80
    case incorrectLength = 0x6700
    case incorrectP1P2 = 0x6B00
    case insNotSupported = 0x6D00
    case deviceNotOnboarded = 0x6D07
    case deviceNotOnboarded2 = 0x6611
    case invalidKcv = 0x9485
    case invalidOffset = 0x9402
    case licensing = 0x6F42
    case lockedDevice = 0x5515
    case maxValueReached = 0x9850
    case memoryProblem = 0x9240
    case missingCriticalParameter = 0x6800
    case noEfSelected = 0x9400
    case notEnoughMemorySpace = 0x6A84
    case ok = 0x9000
    case pinRemainingAttempts = 0x63C0
    case referencedDataNotFound = 0x6A88
    case securityStatusNotSatisfied = 0x6982
    case technicalProblem = 0x6F00
    case unknownApdu = 0x6D02
    case userRefusedOnDevice = 0x5501
    case notEnoughSpace = 0x5102
    case txParsingFailed = 0xB010
}
