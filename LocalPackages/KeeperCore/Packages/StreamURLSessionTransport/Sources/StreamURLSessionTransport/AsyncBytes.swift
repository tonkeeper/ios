//
//  AsyncBytes.swift
//

import Foundation

/// The byte chunks of one streaming response.
///
/// A plain `AsyncThrowingStream` rather than a hand-rolled buffer-plus-continuation: `yield` is
/// synchronous and thread-safe, so chunks keep the order the delegate received them in, and the
/// finish-exactly-once bookkeeping is the stdlib's rather than ours.
///
/// Note the buffering is unbounded, which is deliberate. `AsyncStream`'s bounded policies drop
/// elements, and dropping a chunk of a byte stream corrupts it rather than applying backpressure —
/// `URLSession` has no producer-suspending API to offer here either.
public typealias AsyncBytes = AsyncThrowingStream<ArraySlice<UInt8>, Swift.Error>
