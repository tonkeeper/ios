//
//  Bytewords.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

public enum BytewordsDecodingError: LocalizedError {
    case invalidWord
    case invalidChecksum
    
    public var errorDescription: String? {
        switch self {
        case .invalidWord:
            return "Invalid Bytewords word."
        case .invalidChecksum:
            return "Invalid Bytewords checksum."
        }
    }
}

public struct Bytewords {
    public enum Style {
        case standard
        case uri
        case minimal
    }

    public static func encodedLength(_ len: Int, style: Style = .standard) -> Int {
        switch style {
        case .standard, .uri:
            return len * 4 + (len - 1)
        case .minimal:
            return len * 2
        }
    }

    public static func encode(_ data: Data, style: Style = .standard) -> String {
        switch style {
        case .standard:
            return encode(data, separator: " ")
        case .uri:
            return encode(data, separator: "-")
        case .minimal:
            return encodeMinimal(data)
        }
    }
    
    public static func checksumWords(_ data: Data, style: Style = .standard) -> String {
        let checksum = Self.checksum(of: data)
        return switch style {
        case .standard:
            encodeRaw(checksum, separator: " ")
        case .uri:
            encodeRaw(checksum, separator: "-")
        case .minimal:
            encodeMinimalRaw(checksum)
        }
    }

    public static func decode(_ string: String, style: Style = .standard) throws -> Data {
        switch style {
        case .standard:
            return try decode(string, separator: " ")
        case .uri:
            return try decode(string, separator: "-")
        case .minimal:
            return try decodeMinimal(string)
        }
    }
    
    private static func encodeRaw(_ data: Data, separator: String) -> String {
        let words = data.map { byte in
            indexToBytewords[byte]!
        }
        return words.joined(separator: separator)
    }

    private static func encode(_ data: Data, separator: String) -> String {
        encodeRaw(data + checksum(of: data), separator: separator)
    }
    
    private static func encodeMinimalRaw(_ data: Data) -> String {
        let words = data.map { byte in
            indexToMinimalBytewords[byte]!
        }
        return words.joined(separator: "")
    }

    private static func encodeMinimal(_ data: Data) -> String {
        encodeMinimalRaw(data + checksum(of: data))
    }

    private static func decode(_ string: String, separator: Character) throws -> Data {
        let words = string.split(separator: separator)
        let values = try words.map { word -> UInt8 in
            guard let value = bytewordsToIndex[String(word)] else {
                throw BytewordsDecodingError.invalidWord
            }
            return value
        }
        let data = Data(values)
        return try stripChecksum(from: data)
    }

    private static func decodeMinimal(_ string: String) throws -> Data {
        let words = string.chunked(into: 2)
        let values = try words.map { word -> UInt8 in
            guard let value = minimalBytewordsToIndex[word] else {
                throw BytewordsDecodingError.invalidWord
            }
            return value
        }
        let data = Data(values)
        return try stripChecksum(from: data)
    }

    private static let bytewords = """
    ableacidalsoapexaquaarchatomauntawayaxisbackbaldbarnbeltbetabias\
    bluebodybragbrewbulbbuzzcalmcashcatschefcityclawcodecolacookcost\
    cruxcurlcuspcyandarkdatadaysdelidicedietdoordowndrawdropdrumdull\
    dutyeacheasyechoedgeepicevenexamexiteyesfactfairfernfigsfilmfish\
    fizzflapflewfluxfoxyfreefrogfuelfundgalagamegeargemsgiftgirlglow\
    goodgraygrimgurugushgyrohalfhanghardhawkheathelphighhillholyhope\
    hornhutsicedideaidleinchinkyintoirisironitemjadejazzjoinjoltjowl\
    judojugsjumpjunkjurykeepkenokeptkeyskickkilnkingkitekiwiknoblamb\
    lavalazyleaflegsliarlimplionlistlogoloudloveluaulucklungmainmany\
    mathmazememomenumeowmildmintmissmonknailnavyneednewsnextnoonnote\
    numbobeyoboeomitonyxopenovalowlspaidpartpeckplaypluspoempoolpose\
    puffpumapurrquadquizraceramprealredorichroadrockroofrubyruinruns\
    rustsafesagascarsetssilkskewslotsoapsolosongstubsurfswantacotask\
    taxitenttiedtimetinytoiltombtoystriptunatwinuglyundouniturgeuser\
    vastveryvetovialvibeviewvisavoidvowswallwandwarmwaspwavewaxywebs\
    whatwhenwhizwolfworkyankyawnyellyogayurtzapszerozestzinczonezoom
    """

    private static let indexToBytewords: [UInt8 : String] = {
        var result: [UInt8 : String] = [:]
        var a = bytewords.makeIterator()
        (0...255).forEach { i in
            let word = String((1...4).map { _ in a.next()! })
            result[UInt8(i)] = word
        }
        return result
    }()

    public static let allWords: [String] = {
        var result: [String] = .init()
        result.reserveCapacity(256)
        var a = bytewords.makeIterator()
        (0...255).forEach { i in
            let word = String((1...4).map { _ in a.next()! })
            result.append(word)
        }
        return result
    }()

    private static let indexToMinimalBytewords: [UInt8 : String] = {
        var result: [UInt8 : String] = [:]
        var a = bytewords.makeIterator()
        (0...255).forEach { i in
            let letters = (1...4).map { _ in a.next()! }
            let word = String([letters[0], letters[3]])
            result[UInt8(i)] = word
        }
        return result
    }()

    private static let bytewordsToIndex: [String : UInt8] = {
        var result: [String: UInt8] = [:]
        var a = bytewords.makeIterator()
        (0...255).forEach { i in
            let word = String((1...4).map { _ in a.next()! })
            result[word] = UInt8(i)
        }
        return result
    }()

    private static let minimalBytewordsToIndex: [String: UInt8] = {
        var result: [String: UInt8] = [:]
        var a = bytewords.makeIterator()
        (0...255).forEach { i in
            let letters = (1...4).map { _ in a.next()! }
            let word = String([letters[0], letters[3]])
            result[word] = UInt8(i)
        }
        return result
    }()
    
    public static func checksum(of data: Data) -> Data {
        CRC32.checksum(data).serialized
    }

    private static func stripChecksum(from data: Data) throws -> Data {
        let checksumSize = MemoryLayout<UInt32>.size
        guard data.count > checksumSize else { throw BytewordsDecodingError.invalidChecksum }
        let message = data.prefix(data.count - checksumSize)
        let checksum = CRC32.checksum(message)
        let messageChecksum = deserialize(UInt32.self, Data(data.suffix(checksumSize)))
        guard messageChecksum == checksum else { throw BytewordsDecodingError.invalidChecksum }
        return message
    }
}

protocol Serializable {
    var serialized: Data { get }
}

func serialize<I>(_ n: I, littleEndian: Bool = false) -> Data where I: FixedWidthInteger {
    let count = MemoryLayout<I>.size
    var d = Data(repeating: 0, count: count)
    d.withUnsafeMutableBytes {
        $0.bindMemory(to: I.self).baseAddress!.pointee = littleEndian ? n.littleEndian : n.bigEndian
    }
    return d
}

func deserialize<T, D>(_ t: T.Type, _ data: D, littleEndian: Bool = false) -> T? where T: FixedWidthInteger, D : DataProtocol {
    let size = MemoryLayout<T>.size
    guard data.count >= size else {
        return nil
    }

    var dataBytes = [UInt8](repeating: 0, count: size)
    return dataBytes.withUnsafeMutableBytes {
        data.copyBytes(to: $0, count: size)
        let a = $0.bindMemory(to: T.self).baseAddress!.pointee
        return littleEndian ? T(littleEndian: a) : T(bigEndian: a)
    }
}

extension FixedWidthInteger {
    func serialized(littleEndian: Bool = false) -> Data {
        serialize(self, littleEndian: littleEndian)
    }
}

extension UInt: Serializable {
    var serialized: Data {
        serialize(self)
    }
}

extension UInt8: Serializable {
    var serialized: Data {
        serialize(self)
    }
}

extension UInt16: Serializable {
    var serialized: Data {
        serialize(self)
    }
}

extension UInt32: Serializable {
    var serialized: Data {
        serialize(self)
    }
}

extension UInt64: Serializable {
    var serialized: Data {
        serialize(self)
    }
}

extension Int: Serializable {
    var serialized: Data {
        serialize(self)
    }
}

extension Int8: Serializable {
    var serialized: Data {
        serialize(self)
    }
}

extension Int16: Serializable {
    var serialized: Data {
        serialize(self)
    }
}

extension Int32: Serializable {
    var serialized: Data {
        serialize(self)
    }
}

extension Int64: Serializable {
    var serialized: Data {
        serialize(self)
    }
}
