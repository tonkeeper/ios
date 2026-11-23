import Foundation
import URKit

/// Keeps multipart assembly and reset atomic at the synchronous scanner delegate boundary.
public final class ScannerURDecoder {
    private let lock = NSLock()
    private var decoder = URDecoder()
    private var message: MultipartMessage?

    public init() {}

    public func decode(_ part: String) throws -> UR {
        lock.lock()
        defer { lock.unlock() }

        if let ur = try? URDecoder.decode(part) {
            resetLocked()
            return ur
        }

        guard let incoming = MultipartMessage(part) else { throw URError.noResult }
        if incoming != message {
            resetLocked()
            message = incoming
        }
        decoder.receivePart(part)
        guard let result = decoder.result else { throw URError.noResult }
        resetLocked()
        return try result.get()
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        resetLocked()
    }

    private func resetLocked() {
        decoder = URDecoder()
        message = nil
    }

    private struct MultipartMessage: Equatable {
        let type: String
        let fragmentCount: Int
        let messageLength: Int
        let checksum: UInt32
        let fragmentLength: Int

        init?(_ string: String) {
            let components = string.lowercased().split(separator: "/")
            guard components.count == 3,
                  components[0].hasPrefix("ur:"),
                  let data = try? Bytewords.decode(String(components[2]), style: .minimal),
                  let part = try? FountainEncoder.Part(cbor: data),
                  components[1] == "\(part.seqNum)-\(part.seqLen)"
            else { return nil }
            type = String(components[0])
            fragmentCount = part.seqLen
            messageLength = part.messageLen
            checksum = part.checksum
            fragmentLength = part.data.count
        }
    }
}
