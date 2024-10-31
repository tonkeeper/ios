//
//  Xoshiro256.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation
import CryptoKit

// http://xoshiro.di.unimi.it/xoshiro256starstar.c
// Translated to Swift by Wolf McNally

// For full implementation details, see:
// https://github.com/BlockchainCommons/Research/blob/master/papers/bcr-2024-001-multipart-ur.md

/*  Written in 2018 by David Blackman and Sebastiano Vigna (vigna@acm.org)

To the extent possible under law, the author has dedicated all copyright
and related and neighboring rights to this software to the public domain
worldwide. This software is distributed without any warranty.

See <http://creativecommons.org/publicdomain/zero/1.0/>. */

/* This is xoshiro256** 1.0, one of our all-purpose, rock-solid
   generators. It has excellent (sub-ns) speed, a state (256 bits) that is
   large enough for any parallel application, and it passes all tests we
   are aware of.

   For generating just floating-point numbers, xoshiro256+ is even faster.

   The state must be seeded so that it is not everywhere zero. If you have
   a 64-bit seed, we suggest to seed a splitmix64 generator and use its
   output to fill s. */
final class Xoshiro256 : RandomNumberGenerator {
    var state: [UInt64]

    init(state: [UInt64]) {
        assert(state.count == 4)
        self.state = state
    }

    convenience init(digest: SHA256Digest) {
        var s = [UInt64](repeating: 0, count: 4)
        digest.withUnsafeBytes { p in
            for i in 0 ..< 4 {
                let o = i * 8
                var v: UInt64 = 0
                for n in 0 ..< 8 {
                    v <<= 8
                    v |= UInt64(p[o + n])
                }
                s[i] = v
            }
        }
        self.init(state: s)
    }

    convenience init(seed: Data) {
        self.init(digest: SHA256.hash(data: seed))
    }

    convenience init(string: String) {
        self.init(seed: string.utf8Data)
    }

    convenience init(crc32: UInt32) {
        self.init(seed: crc32.serialized)
    }

    func next() -> UInt64 {
        func rotl(_ x: UInt64, _ k: Int) -> UInt64 {
            (x << k) | (x >> (64 - k))
        }

        let result = rotl(state[1] &* 5, 7) &* 9
        let t = state[1] << 17

        state[2] ^= state[0]
        state[3] ^= state[1]
        state[1] ^= state[2]
        state[0] ^= state[3]

        state[2] ^= t

        state[3] = rotl(state[3], 45)

        return result
    }

    func nextDouble() -> Double {
        Double(next()) / (Double(UInt64.max) + 1)
    }

    func nextInt(in range: Range<Int>) -> Int {
        Int(nextDouble() * Double(range.count)) + range.lowerBound
    }

    func nextInt(in range: ClosedRange<Int>) -> Int {
        Int(nextDouble() * Double(range.count)) + range.lowerBound
    }

    func nextByte() -> UInt8 {
        UInt8(nextInt(in: 0 ... 255))
    }

    func nextData(count: Int) -> Data {
        let bytes = (0 ..< count).map { _ in nextByte() }
        return Data(bytes)
    }

    /* This is the jump function for the generator. It is equivalent
       to 2^128 calls to next() it can be used to generate 2^128
       non-overlapping subsequences for parallel computations. */
    func jump() {
        let JUMP: [UInt64] = [ 0x180ec6d33cfd0aba, 0xd5a61266f0c9392c, 0xa9582618e03fc9aa, 0x39abdc4529b1661c ]

        var s0: UInt64 = 0
        var s1: UInt64 = 0
        var s2: UInt64 = 0
        var s3: UInt64 = 0

        for j in JUMP {
            for b in 0 ..< 64 {
                if (j & (1 << b)) != 0 {
                    s0 ^= state[0]
                    s1 ^= state[1]
                    s2 ^= state[2]
                    s3 ^= state[3]
                }
                _ = next()
            }
        }

        state[0] = s0
        state[1] = s1
        state[2] = s2
        state[3] = s3
    }

    /* This is the long-jump function for the generator. It is equivalent to
       2^192 calls to next() it can be used to generate 2^64 starting points,
       from each of which jump() will generate 2^64 non-overlapping
       subsequences for parallel distributed computations. */
    func longJump() {
        let LONG_JUMP: [UInt64] = [ 0x76e15d3efefdcbbf, 0xc5004e441c522fb3, 0x77710069854ee241, 0x39109bb02acbe635 ]

        var s0: UInt64 = 0
        var s1: UInt64 = 0
        var s2: UInt64 = 0
        var s3: UInt64 = 0

        for j in LONG_JUMP {
            for b in 0 ..< 64 {
                if (j & (1 << b)) != 0 {
                    s0 ^= state[0]
                    s1 ^= state[1]
                    s2 ^= state[2]
                    s3 ^= state[3]
                }
                _ = next()
            }
        }

        state[0] = s0
        state[1] = s1
        state[2] = s2
        state[3] = s3
    }
}
