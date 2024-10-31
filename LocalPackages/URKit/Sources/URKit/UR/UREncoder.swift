//
//  UREncoder.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

public final class UREncoder {
    /// Encode a single-part UR.
    public static func encode(_ ur: UR) -> String {
        let body = Bytewords.encode(ur.cbor.cborData, style: .minimal)
        return encodeUR([ur.type, body])
    }
    
    public static func checksumWords(_ ur: UR, style: Bytewords.Style = .standard) -> String {
        Bytewords.checksumWords(ur.cbor.cborData, style: style)
    }

    private let ur: UR
    private let fountainEncoder: FountainEncoder

    public var messageLen: Int { fountainEncoder.messageLen }
    public var fragmentLen: Int { fountainEncoder.fragmentLen }
    public var maxFragmentLen: Int { fountainEncoder.maxFragmentLen }
    public var seqNum: UInt32 { fountainEncoder.seqNum }
    public var seqLen: Int { fountainEncoder.seqLen }
    public var lastFragmentIndexes: Set<Int> { fountainEncoder.lastFragmentIndexes }

    /// Start encoding a (possibly) multi-part UR.
    public init(_ ur: UR, maxFragmentLen: Int, firstSeqNum: UInt32 = 0, minFragmentLen: Int = 10) {
        self.ur = ur
        fountainEncoder = FountainEncoder(message: ur.cbor.cborData, maxFragmentLen: maxFragmentLen, firstSeqNum: firstSeqNum, minFragmentLen: minFragmentLen)
    }

    /// `true` if the minimal number of parts to transmit the message have been
    /// generated. Parts generated when this is `true` will be fountain codes
    /// containing various mixes of the part data.
    public var isComplete: Bool { fountainEncoder.isComplete }

    /// `true` if this UR can be contained in a single part. If `true`, repeated
    /// calls to `nextPart()` will all return the same single-part UR.
    public var isSinglePart: Bool { fountainEncoder.isSinglePart }
    
    /// Returns value `<=` 1.0 if single part, `>` 1.0 if multi-part.
    public var messagePercentOfMaxFragmentLen: Double {
        fountainEncoder.messagePercentOfMaxFragmentLen
    }

    public func nextPart() -> String {
        let part = fountainEncoder.nextPart()
        if isSinglePart {
            return Self.encode(ur)
        } else {
            return Self.encodePart(type: ur.type, part: part)
        }
    }

    private static func encodePart(type: String, part: FountainEncoder.Part) -> String {
        let seq = "\(part.seqNum)-\(part.seqLen)"
        let body = Bytewords.encode(part.cbor, style: .minimal)
        return encodeUR([type, seq, body])
    }

    private static func encodeURI(scheme: String, pathComponents: [String]) -> String {
        let path = pathComponents.joined(separator: "/")
        return [scheme, path].joined(separator: ":")
    }

    private static func encodeUR(_ pathComponents: [String]) -> String {
        encodeURI(scheme: "ur", pathComponents: pathComponents)
    }
}
