//
//  RandomSampler.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

// Random-number sampling using the Walker-Vose alias method,
// as described by Keith Schwarz (2011)
// http://www.keithschwarz.com/darts-dice-coins

// Based on C implementation:
// https://jugit.fz-juelich.de/mlz/ransampl

// Translated to Swift by Wolf McNally

// For full implementation details, see:
// https://github.com/BlockchainCommons/Research/blob/master/papers/bcr-2024-001-multipart-ur.md

final class RandomSampler {
    private let probs: [Double]
    private let aliases: [Int]

    init(_ probs: [Double]) {
        probs.forEach { precondition($0 >= 0) }

        // Normalize given probabilities
        let sum = probs.reduce(0, +)
        precondition(sum > 0)

        let n = probs.count
        var P = probs.map { $0 * Double(n) / sum }

        var S: [Int] = []
        var L: [Int] = []

        // Set separate index lists for small and large probabilities:
        for i in (0 ... n-1).reversed() {
            // at variance from Schwarz, we reverse the index order
            if P[i] < 1 {
                S.append(i)
            } else {
                L.append(i)
            }
        }

        // Work through index lists
        var probs = [Double](repeating: 0, count: n)
        var aliases = [Int](repeating: 0, count: n)
        while !S.isEmpty && !L.isEmpty {
            let a = S.removeLast() // Schwarz's l
            let g = L.removeLast() // Schwarz's g
            probs[a] = P[a]
            aliases[a] = g
            P[g] += P[a] - 1
            if P[g] < 1 {
                S.append(g)
            } else {
                L.append(g)
            }
        }

        while !L.isEmpty {
            probs[L.removeLast()] = 1
        }

        while !S.isEmpty {
            // can only happen through numeric instability
            probs[S.removeLast()] = 1
        }

        self.probs = probs
        self.aliases = aliases
    }

    func next(_ rng: () -> Double) -> Int {
        let r1 = rng()
        let r2 = rng()
        let n = probs.count
        let i = Int(Double(n) * r1)
        return r2 < probs[i] ? i : aliases[i]
    }

    func next<G: RandomNumberGenerator>(using generator: inout G) -> Int {
        next { Double.random(in: 0...1, using: &generator ) }
    }

    func next() -> Int {
        var g = SystemRandomNumberGenerator()
        return next(using: &g)
    }
}
