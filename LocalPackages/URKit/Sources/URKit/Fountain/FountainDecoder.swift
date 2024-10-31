//
//  FountainDecoder.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

// Implements Luby transform code rateless decoding
// https://en.wikipedia.org/wiki/Luby_transform_code

// For full implementation details, see:
// https://github.com/BlockchainCommons/Research/blob/master/papers/bcr-2024-001-multipart-ur.md

public typealias FragmentIndexes = Set<Int>

public enum FountainDecoderError: LocalizedError {
    case invalidChecksum
    
    public var errorDescription: String? {
        switch self {
        case .invalidChecksum:
            return "FountainDecoder: Invalid checksum."
        }
    }
}

public final class FountainDecoder {
    typealias PartDict = [FragmentIndexes: Part]

    public var expectedFragmentCount: Int! { return expectedFragmentIndexes?.count }
    public private(set) var receivedFragmentIndexes: FragmentIndexes = []
    public private(set) var lastFragmentIndexes: FragmentIndexes!
    public private(set) var processedPartsCount = 0
    public private(set) var result: Result<Data, Error>?

    var expectedFragmentIndexes: FragmentIndexes!
    var expectedFragmentLen: Int!
    var expectedMessageLen: Int!
    var expectedChecksum: UInt32!

    var simpleParts: PartDict = [:]
    var mixedParts: PartDict = [:]
    var queuedParts: [Part] = []
    
    private var fragmentChooser: FragmentChooser!

    public var estimatedPercentComplete: Double {
        guard result == nil else { return 1 }
        guard let expectedPartCount = expectedFragmentCount else { return 0 }
        let estimatedInputParts = Double(expectedPartCount) * 1.75
        return min(0.99, Double(processedPartsCount) / estimatedInputParts)
    }

    struct Part {
        let fragmentIndexes: FragmentIndexes
        let data: Data

        // Only used for simple parts
        var index: Int { fragmentIndexes.first! }

        init(_ p: FountainEncoder.Part, fragmentIndexes: FragmentIndexes) {
            self.data = p.data
            self.fragmentIndexes = fragmentIndexes
        }

        init(fragmentIndexes: FragmentIndexes, data: Data) {
            self.fragmentIndexes = fragmentIndexes
            self.data = data
        }

        var isSimple: Bool {
            fragmentIndexes.count == 1
        }
    }

    public init() {
    }

    public func receivePart(_ encoderPart: FountainEncoder.Part) -> Bool {
        // Don't process the part if we're already done
        guard result == nil else { return false }

        // Don't continue if this part doesn't validate
        guard validatePart(encoderPart) else { return false }

        if fragmentChooser == nil {
            self.fragmentChooser = FragmentChooser(seqLen: encoderPart.seqLen, checksum: encoderPart.checksum)
        }

        // Add this part to the queue
        let fragmentIndexes = fragmentChooser.chooseFragments(at: encoderPart.seqNum)
        let part = Part(encoderPart, fragmentIndexes: fragmentIndexes)
        lastFragmentIndexes = part.fragmentIndexes
        enqueue(part)

        // Process the queue until we're done or the queue is empty
        processQueue()

        // Keep track of how many parts we've processed
        processedPartsCount += 1
        //printPartEnd()
        return true
    }

    private func enqueue(_ part: Part) {
        queuedParts.append(part)
    }

    func printPartEnd() {
        let parts = expectedFragmentCount != nil ? String(expectedFragmentCount) : "nil"
        let percent = Int((estimatedPercentComplete * 100).rounded())
        print("processed: \(processedPartsCount), expected: \(parts), received: \(receivedFragmentIndexes.count), percent: \(percent)%")
    }

    func printPart(_ part: Part) {
        let indexes = Array(part.fragmentIndexes).sorted()
        print("part indexes: \(indexes)")
    }

    private func resultDescription() -> String {
        let desc: String
        switch result {
        case nil:
            desc = "nil"
        case let .success(message)?:
            desc = "\(message.count) bytes"
        case let .failure(error)?:
            desc = error.localizedDescription
        }
        return desc
    }

    func printState() {
        let parts = expectedFragmentCount != nil ? String(expectedFragmentCount) : "nil"
        let received = Array(receivedFragmentIndexes).sorted()
        let mixed = mixedParts.keys.map( { Array($0).sorted() } ).sorted(by: { $0.lexicographicallyPrecedes($1) } )
        let queued = queuedParts.count
        print("parts: \(parts), received: \(received), mixed: \(mixed), queued: \(queued), result: \(resultDescription())")
    }

    private func processQueue() {
        // Process the queue until we're done or the queue is empty
        while result == nil && !queuedParts.isEmpty {
            let part = queuedParts.removeFirst()
            //printPart(part)
            if part.isSimple {
                processSimplePart(part)
            } else {
                processMixedPart(part)
            }
            //printState()
        }
    }

    private func reduceMixed(by part: Part) {
        // Reduce all the current mixed parts by the given part
        let reducedParts = mixedParts.values.map {
            reducePart($0, by: part)
        }

        // Collect all the remaining mixed parts
        var newMixed: PartDict = [:]
        reducedParts.forEach { reducedPart in
            // If this reduced part is now simple
            if reducedPart.isSimple {
                // Add it to the queue
                enqueue(reducedPart)
            } else {
                // Otherwise, add it to the list of current mixed parts
                newMixed[reducedPart.fragmentIndexes] = reducedPart
            }
        }
        mixedParts = newMixed
    }

    // Reduce part `a` by part `b`
    private func reducePart(_ a: Part, by b: Part) -> Part {
        // If the fragments mixed into `b` are a strict (proper) subset of those in `a`...
        if b.fragmentIndexes.isStrictSubset(of: a.fragmentIndexes) {
            // The new fragments in the revised part are `a` - `b`.
            let newIndexes = a.fragmentIndexes.subtracting(b.fragmentIndexes)
            // The new data in the revised part are `a` XOR `b`
            let newData = a.data.xor(with: b.data)
            return Part(fragmentIndexes: newIndexes, data: newData)
        } else {
            // `a` is not reducible by `b`, so return a
            return a
        }
    }

    private func processSimplePart(_ part: Part) {
        // Don't process duplicate parts
        let fragmentIndex = part.index
        guard !receivedFragmentIndexes.contains(fragmentIndex) else { return }

        // Record this part
        simpleParts[part.fragmentIndexes] = part
        receivedFragmentIndexes.insert(fragmentIndex)

        // If we've received all the parts
        if receivedFragmentIndexes == expectedFragmentIndexes {
            // Reassemble the message from its fragments
            let sortedParts = Array(simpleParts.values).sorted { $0.index < $1.index }
            let fragments = sortedParts.map { $0.data }
            let message = Self.joinFragments(fragments, messageLen: expectedMessageLen)

            // Verify the message checksum and note success or failure
            let checksum = CRC32.checksum(message)
            if checksum == expectedChecksum {
                result = .success(message)
            } else {
                result = .failure(FountainDecoderError.invalidChecksum)
            }
        } else {
            // Reduce all the mixed parts by this part
            reduceMixed(by: part)
        }
    }

    private func processMixedPart(_ part: Part) {
        // Don't process duplicate parts
        guard !mixedParts.keys.contains(part.fragmentIndexes) else { return }

        // Reduce this part by all the others
        let p = [simpleParts.values, mixedParts.values].joined().reduce(part) {
            reducePart($0, by: $1)
        }

        // If the part is now simple
        if p.isSimple {
            // Add it to the queue
            enqueue(p)
        } else {
            // Reduce all the mixed parts by this one
            reduceMixed(by: p)
            // Record this new mixed part
            mixedParts[p.fragmentIndexes] = p
        }
    }

    private func validatePart(_ part: FountainEncoder.Part) -> Bool {
        // If this is the first part we've seen
        if expectedFragmentIndexes == nil {
            // Record the things that all the other parts we see will have to match to be valid.
            expectedFragmentIndexes = Set(0 ..< part.seqLen)
            expectedMessageLen = part.messageLen
            expectedChecksum = part.checksum
            expectedFragmentLen = part.data.count
        } else {
            // If this part's values don't match the first part's values
            guard expectedFragmentCount == part.seqLen,
                  expectedMessageLen == part.messageLen,
                  expectedChecksum == part.checksum,
                  expectedFragmentLen == part.data.count
            else {
                // Throw away the part
                return false
            }
        }
        // This part should be processed
        return true
    }

    // Join all the fragments of a message together, throwing away any padding
    static func joinFragments(_ fragments: [Data], messageLen: Int) -> Data {
        var message = Data(fragments.joined())
        let padding = message.count - messageLen
        message.removeLast(padding)
        return message
    }
}
