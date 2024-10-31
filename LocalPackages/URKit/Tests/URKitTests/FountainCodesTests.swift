//
//  FountainCodesTests.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import XCTest
@testable import URKit

class FountainCodesTests: XCTestCase {
    func testCRC32() {
        let string = "Wolf"
        let checksum = CRC32.checksum(string.utf8Data)
        XCTAssertEqual(checksum, 0x598c84dc)
        XCTAssertEqual(checksum.serialized.hex, "598c84dc")
    }
    
    func testCRC32_2() {
        let data = toData(hex:"916ec65cf77cadf55cd7f9cda1a1030026ddd42e905b77adc36e4f2d3ccba44f7f04f2de44f42d84c374a0e149136f25b01852545961d55f7f7a8cde6d0e2ec43f3b2dcb644a2209e8c9e34af5c4747984a5e873c9cf5f965e25ee29039fdf8ca74f1c769fc07eb7ebaec46e0695aea6cbd60b3ec4bbff1b9ffe8a9e7240129377b9d3711ed38d412fbb4442256f1e6f595e0fc57fed451fb0a0101fb76b1fb1e1b88cfdfdaa946294a47de8fff173f021c0e6f65b05c0a494e50791270a0050a73ae69b6725505a2ec8a5791457c9876dd34aadd192a53aa0dc66b556c0c215c7ceb8248b717c22951e65305b56a3706e3e86eb01c803bbf915d80edcd64d4d41977fa6f78dc07eecd072aae5bc8a852397e06034dba6a0b570797c3a89b16673c94838d884923b8186ee2db5c98407cab15e13678d072b43e406ad49477c2e45e85e52ca82a94f6df7bbbe7afbed3a3a830029f29090f25217e48d1f42993a640a67916aa7480177354cc7440215ae41e4d02eae9a191233a6d4922a792c1b7244aa879fefdb4628dc8b0923568869a983b8c661ffab9b2ed2c149e38d41fba090b94155adbed32f8b18142ff0d7de4eeef2b04adf26f2456b46775c6c20b37602df7da179e2332feba8329bbb8d727a138b4ba7a503215eda2ef1e953d89383a382c11d3f2cad37a4ee59a91236a3e56dcf89f6ac81dd4159989c317bd649d9cbc617f73fe10033bd288c60977481a09b343d3f676070e67da757b86de27bfca74392bac2996f7822a7d8f71a489ec6180390089ea80a8fcd6526413ec6c9a339115f111d78ef21d456660aa85f790910ffa2dc58d6a5b93705caef1091474938bd312427021ad1eeafbd19e0d916ddb111fabd8dcab5ad6a6ec3a9c6973809580cb2c164e26686b5b98cfb017a337968c7daaa14ae5152a067277b1b3902677d979f8e39cc2aafb3bc06fcf69160a853e6869dcc09a11b5009f91e6b89e5b927ab1527a735660faa6012b420dd926d940d742be6a64fb01cdc0cff9faa323f02ba41436871a0eab851e7f5782d10fbefde2a7e9ae9dc1e5c2c48f74f6c824ce9ef3c89f68800d44587bedc4ab417cfb3e7447d90e1e417e6e05d30e87239d3a5d1d45993d4461e60a0192831640aa32dedde185a371ded2ae15f8a93dba8809482ce49225daadfbb0fec629e23880789bdf9ed73be57fa84d555134630e8d0f7df48349f29869a477c13ccca9cd555ac42ad7f568416c3d61959d0ed568b2b81c7771e9088ad7fd55fd4386bafbf5a528c30f107139249357368ffa980de2c76ddd9ce4191376be0e6b5170010067e2e75ebe2d2904aeb1f89d5dc98cd4a6f2faaa8be6d03354c990fd895a97feb54668473e9d942bb99e196d897e8f1b01625cf48a7b78d249bb4985c065aa8cd1402ed2ba1b6f908f63dcd84b66425df")!
        let checksum = CRC32.checksum(data)
        XCTAssertEqual(checksum, 0x2f19f3bb)
        XCTAssertEqual(checksum.serialized.hex, "2f19f3bb")
    }

    func testRNG1() {
        let rng = Xoshiro256(string: "Wolf")
        let numbers = (0 ..< 100).map { _ in Int(rng.next() % 100) }
        let expectedNumbers = [42, 81, 85, 8, 82, 84, 76, 73, 70, 88, 2, 74, 40, 48, 77, 54, 88, 7, 5, 88, 37, 25, 82, 13, 69, 59, 30, 39, 11, 82, 19, 99, 45, 87, 30, 15, 32, 22, 89, 44, 92, 77, 29, 78, 4, 92, 44, 68, 92, 69, 1, 42, 89, 50, 37, 84, 63, 34, 32, 3, 17, 62, 40, 98, 82, 89, 24, 43, 85, 39, 15, 3, 99, 29, 20, 42, 27, 10, 85, 66, 50, 35, 69, 70, 70, 74, 30, 13, 72, 54, 11, 5, 70, 55, 91, 52, 10, 43, 43, 52]
        XCTAssertEqual(numbers, expectedNumbers)
    }

    func testRNG2() {
        let checksum = CRC32.checksum("Wolf".utf8Data)
        let rng = Xoshiro256(crc32: checksum)
        let numbers = (0 ..< 100).map { _ in Int(rng.next() % 100) }
        let expectedNumbers = [88, 44, 94, 74, 0, 99, 7, 77, 68, 35, 47, 78, 19, 21, 50, 15, 42, 36, 91, 11, 85, 39, 64, 22, 57, 11, 25, 12, 1, 91, 17, 75, 29, 47, 88, 11, 68, 58, 27, 65, 21, 54, 47, 54, 73, 83, 23, 58, 75, 27, 26, 15, 60, 36, 30, 21, 55, 57, 77, 76, 75, 47, 53, 76, 9, 91, 14, 69, 3, 95, 11, 73, 20, 99, 68, 61, 3, 98, 36, 98, 56, 65, 14, 80, 74, 57, 63, 68, 51, 56, 24, 39, 53, 80, 57, 51, 81, 3, 1, 30]
        XCTAssertEqual(numbers, expectedNumbers)
    }

    func testRNG3() {
        let rng = Xoshiro256(string: "Wolf")
        let numbers = (0 ..< 100).map { _ in Int(rng.nextInt(in: 1...10)) }
        let expectedNumbers = [6, 5, 8, 4, 10, 5, 7, 10, 4, 9, 10, 9, 7, 7, 1, 1, 2, 9, 9, 2, 6, 4, 5, 7, 8, 5, 4, 2, 3, 8, 7, 4, 5, 1, 10, 9, 3, 10, 2, 6, 8, 5, 7, 9, 3, 1, 5, 2, 7, 1, 4, 4, 4, 4, 9, 4, 5, 5, 6, 9, 5, 1, 2, 8, 3, 3, 2, 8, 4, 3, 2, 1, 10, 8, 9, 3, 10, 8, 5, 5, 6, 7, 10, 5, 8, 9, 4, 6, 4, 2, 10, 2, 1, 7, 9, 6, 7, 4, 2, 5]
        XCTAssertEqual(numbers, expectedNumbers)
    }

    func testFindFragmentLength() {
        XCTAssertEqual(FountainEncoder.findNominalFragmentLength(messageLen: 12_345, minFragmentLen: 1_005, maxFragmentLen: 1_955), 1_764)
        XCTAssertEqual(FountainEncoder.findNominalFragmentLength(messageLen: 12_345, minFragmentLen: 1_005, maxFragmentLen: 30_000), 12_345)
    }

    func testRandomSampler() {
        // Each successive value should appear roughly twice as often as the previous value.
        let sampler = RandomSampler([1, 2, 4, 8])
        let rng = Xoshiro256(string: "Wolf")
        let samplesCount = 500
        let samples = (0 ..< samplesCount).map { _ in sampler.next( { rng.nextDouble() } ) }
        let expectedSamples = [3, 3, 3, 3, 3, 3, 3, 0, 2, 3, 3, 3, 3, 1, 2, 2, 1, 3, 3, 2, 3, 3, 1, 1, 2, 1, 1, 3, 1, 3, 1, 2, 0, 2, 1, 0, 3, 3, 3, 1, 3, 3, 3, 3, 1, 3, 2, 3, 2, 2, 3, 3, 3, 3, 2, 3, 3, 0, 3, 3, 3, 3, 1, 2, 3, 3, 2, 2, 2, 1, 2, 2, 1, 2, 3, 1, 3, 0, 3, 2, 3, 3, 3, 3, 3, 3, 3, 3, 2, 3, 1, 3, 3, 2, 0, 2, 2, 3, 1, 1, 2, 3, 2, 3, 3, 3, 3, 2, 3, 3, 3, 3, 3, 2, 3, 1, 2, 1, 1, 3, 1, 3, 2, 2, 3, 3, 3, 1, 3, 3, 3, 3, 3, 3, 3, 3, 2, 3, 2, 3, 3, 1, 2, 3, 3, 1, 3, 2, 3, 3, 3, 2, 3, 1, 3, 0, 3, 2, 1, 1, 3, 1, 3, 2, 3, 3, 3, 3, 2, 0, 3, 3, 1, 3, 0, 2, 1, 3, 3, 1, 1, 3, 1, 2, 3, 3, 3, 0, 2, 3, 2, 0, 1, 3, 3, 3, 2, 2, 2, 3, 3, 3, 3, 3, 2, 3, 3, 3, 3, 2, 3, 3, 2, 0, 2, 3, 3, 3, 3, 2, 1, 1, 1, 2, 1, 3, 3, 3, 2, 2, 3, 3, 1, 2, 3, 0, 3, 2, 3, 3, 3, 3, 0, 2, 2, 3, 2, 2, 3, 3, 3, 3, 1, 3, 2, 3, 3, 3, 3, 3, 2, 2, 3, 1, 3, 0, 2, 1, 3, 3, 3, 3, 3, 3, 3, 3, 1, 3, 3, 3, 3, 2, 2, 2, 3, 1, 1, 3, 2, 2, 0, 3, 2, 1, 2, 1, 0, 3, 3, 3, 2, 2, 3, 2, 1, 2, 0, 0, 3, 3, 2, 3, 3, 2, 3, 3, 3, 3, 3, 2, 2, 2, 3, 3, 3, 3, 3, 1, 1, 3, 2, 2, 3, 1, 1, 0, 1, 3, 2, 3, 3, 2, 3, 3, 2, 3, 3, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 1, 2, 3, 3, 2, 2, 2, 2, 3, 3, 2, 0, 2, 1, 3, 3, 3, 3, 0, 3, 3, 3, 3, 2, 2, 3, 1, 3, 3, 3, 2, 3, 3, 3, 2, 3, 3, 3, 3, 2, 3, 2, 1, 3, 3, 3, 3, 2, 2, 0, 1, 2, 3, 2, 0, 3, 3, 3, 3, 3, 3, 1, 3, 3, 2, 3, 2, 2, 3, 3, 3, 3, 3, 2, 2, 3, 3, 2, 2, 2, 1, 3, 3, 3, 3, 1, 2, 3, 2, 3, 3, 2, 3, 2, 3, 3, 3, 2, 3, 1, 2, 3, 2, 1, 1, 3, 3, 2, 3, 3, 2, 3, 3, 0, 0, 1, 3, 3, 2, 3, 3, 3, 3, 1, 3, 3, 0, 3, 2, 3, 3, 1, 3, 3, 3, 3, 3, 3, 3, 0, 3, 3, 2];
        XCTAssertEqual(samples, expectedSamples)
        
        var totals: [Int: Int] = [:]
        for sample in samples {
            totals[sample, default: 0] += 1
        }
        let sortedValues = Array(totals)
            .sorted { $0.key < $1.key }
            .map { $0.value }
        // Nominal values for 500 samples: [33, 67, 133, 267]
        XCTAssertEqual(sortedValues, [28, 68, 130, 274])
        XCTAssertEqual(sortedValues.reduce(0, +), samplesCount)
    }

    func testShuffle() {
        let rng = Xoshiro256(string: "Wolf")
        let indexes = 1...10
        let values = Array(indexes)
        let result = indexes.map { count in
            shuffled(values, rng: rng, count: count)
        }
        let expectedResult = [
            [6],
            [5, 8],
            [4, 10, 5], 
            [7, 10, 3, 8],
            [10, 8, 6, 5, 1],
            [1, 3, 9, 8, 4, 6],
            [4, 6, 8, 9, 3, 2, 1],
            [3, 9, 7, 4, 5, 1, 10, 8],
            [3, 10, 2, 6, 8, 5, 7, 9, 1],
            [1, 5, 3, 8, 2, 6, 7, 9, 4, 10]
        ]
        XCTAssertEqual(result, expectedResult)
    }

    func testPartitionAndJoin() {
        let message = makeMessage(len: 1024)
        let fragmentLen = FountainEncoder.findNominalFragmentLength(messageLen: message.count, minFragmentLen: 10, maxFragmentLen: 100)
        let fragments = FountainEncoder.partitionMessage(message, fragmentLen: fragmentLen)
        let fragmentsHex = fragments.map { $0.hex }
        let expectedFragments = [
            "916ec65cf77cadf55cd7f9cda1a1030026ddd42e905b77adc36e4f2d3ccba44f7f04f2de44f42d84c374a0e149136f25b01852545961d55f7f7a8cde6d0e2ec43f3b2dcb644a2209e8c9e34af5c4747984a5e873c9cf5f965e25ee29039f",
            "df8ca74f1c769fc07eb7ebaec46e0695aea6cbd60b3ec4bbff1b9ffe8a9e7240129377b9d3711ed38d412fbb4442256f1e6f595e0fc57fed451fb0a0101fb76b1fb1e1b88cfdfdaa946294a47de8fff173f021c0e6f65b05c0a494e50791",
            "270a0050a73ae69b6725505a2ec8a5791457c9876dd34aadd192a53aa0dc66b556c0c215c7ceb8248b717c22951e65305b56a3706e3e86eb01c803bbf915d80edcd64d4d41977fa6f78dc07eecd072aae5bc8a852397e06034dba6a0b570",
            "797c3a89b16673c94838d884923b8186ee2db5c98407cab15e13678d072b43e406ad49477c2e45e85e52ca82a94f6df7bbbe7afbed3a3a830029f29090f25217e48d1f42993a640a67916aa7480177354cc7440215ae41e4d02eae9a1912",
            "33a6d4922a792c1b7244aa879fefdb4628dc8b0923568869a983b8c661ffab9b2ed2c149e38d41fba090b94155adbed32f8b18142ff0d7de4eeef2b04adf26f2456b46775c6c20b37602df7da179e2332feba8329bbb8d727a138b4ba7a5",
            "03215eda2ef1e953d89383a382c11d3f2cad37a4ee59a91236a3e56dcf89f6ac81dd4159989c317bd649d9cbc617f73fe10033bd288c60977481a09b343d3f676070e67da757b86de27bfca74392bac2996f7822a7d8f71a489ec6180390",
            "089ea80a8fcd6526413ec6c9a339115f111d78ef21d456660aa85f790910ffa2dc58d6a5b93705caef1091474938bd312427021ad1eeafbd19e0d916ddb111fabd8dcab5ad6a6ec3a9c6973809580cb2c164e26686b5b98cfb017a337968",
            "c7daaa14ae5152a067277b1b3902677d979f8e39cc2aafb3bc06fcf69160a853e6869dcc09a11b5009f91e6b89e5b927ab1527a735660faa6012b420dd926d940d742be6a64fb01cdc0cff9faa323f02ba41436871a0eab851e7f5782d10",
            "fbefde2a7e9ae9dc1e5c2c48f74f6c824ce9ef3c89f68800d44587bedc4ab417cfb3e7447d90e1e417e6e05d30e87239d3a5d1d45993d4461e60a0192831640aa32dedde185a371ded2ae15f8a93dba8809482ce49225daadfbb0fec629e",
            "23880789bdf9ed73be57fa84d555134630e8d0f7df48349f29869a477c13ccca9cd555ac42ad7f568416c3d61959d0ed568b2b81c7771e9088ad7fd55fd4386bafbf5a528c30f107139249357368ffa980de2c76ddd9ce4191376be0e6b5",
            "170010067e2e75ebe2d2904aeb1f89d5dc98cd4a6f2faaa8be6d03354c990fd895a97feb54668473e9d942bb99e196d897e8f1b01625cf48a7b78d249bb4985c065aa8cd1402ed2ba1b6f908f63dcd84b66425df00000000000000000000"
        ]
        XCTAssertEqual(fragmentsHex, expectedFragments)
        let rejoinedMessage = FountainDecoder.joinFragments(fragments, messageLen: message.count)
        XCTAssertEqual(message, rejoinedMessage)
    }

    func testDegreeChooser() {
        let message = makeMessage(len: 1024)
        let fragmentLen = FountainEncoder.findNominalFragmentLength(messageLen: message.count, minFragmentLen: 10, maxFragmentLen: 100)
        let fragments = FountainEncoder.partitionMessage(message, fragmentLen: fragmentLen)
        let seqLen = fragments.count
        let degreeChooser = DegreeChooser(seqLen: seqLen)
        let rng = Xoshiro256(string: "Wolf")
        let degrees = (1...1000).map { _ in degreeChooser.chooseDegree(using: rng) }
        let expectedDegrees = [7, 9, 2, 1, 4, 2, 1, 1, 3, 10, 7, 1, 1, 4, 3, 8, 6, 2, 3, 2, 1, 1, 4, 5, 8, 4, 4, 1, 6, 1, 5, 2, 3, 3, 5, 2, 1, 10, 2, 5, 1, 1, 1, 5, 5, 11, 1, 1, 8, 2, 1, 1, 2, 1, 1, 1, 1, 1, 1, 11, 1, 1, 5, 1, 1, 1, 3, 7, 3, 3, 2, 2, 4, 2, 1, 3, 1, 1, 8, 2, 1, 1, 2, 7, 1, 1, 2, 1, 2, 1, 4, 1, 1, 1, 2, 1, 8, 1, 5, 4, 2, 1, 1, 1, 1, 4, 1, 8, 1, 5, 4, 9, 1, 8, 6, 6, 7, 5, 4, 8, 5, 1, 2, 2, 11, 10, 1, 4, 3, 1, 2, 1, 2, 5, 1, 6, 2, 1, 3, 1, 8, 6, 3, 8, 1, 4, 1, 7, 6, 11, 1, 6, 1, 5, 5, 1, 3, 2, 4, 6, 3, 5, 1, 8, 1, 1, 1, 11, 3, 1, 2, 1, 4, 1, 2, 7, 5, 5, 5, 4, 6, 4, 3, 2, 3, 9, 1, 2, 3, 1, 2, 2, 5, 1, 1, 10, 3, 7, 2, 6, 1, 1, 1, 1, 3, 9, 1, 3, 1, 8, 4, 1, 3, 2, 3, 1, 1, 2, 4, 3, 4, 4, 4, 2, 6, 1, 7, 10, 3, 8, 1, 7, 6, 7, 1, 1, 1, 3, 11, 1, 1, 1, 2, 2, 3, 2, 8, 3, 1, 1, 2, 1, 3, 1, 3, 10, 1, 9, 11, 10, 3, 2, 5, 6, 1, 3, 3, 5, 1, 8, 8, 1, 2, 3, 1, 7, 6, 1, 11, 4, 9, 1, 1, 8, 1, 5, 3, 1, 8, 1, 1, 1, 3, 4, 2, 5, 1, 2, 10, 1, 8, 2, 11, 7, 4, 9, 2, 1, 1, 1, 3, 10, 1, 2, 1, 1, 8, 1, 1, 7, 1, 2, 9, 1, 1, 1, 11, 6, 6, 1, 8, 8, 4, 5, 6, 3, 5, 1, 7, 9, 1, 9, 2, 7, 8, 1, 1, 1, 2, 2, 2, 1, 8, 8, 2, 3, 2, 5, 8, 1, 5, 1, 3, 8, 8, 10, 2, 8, 3, 9, 3, 5, 2, 4, 2, 2, 2, 10, 6, 2, 2, 2, 11, 5, 4, 11, 1, 6, 10, 1, 10, 8, 1, 10, 6, 1, 2, 1, 3, 5, 1, 1, 4, 10, 2, 7, 2, 5, 8, 2, 2, 3, 11, 1, 6, 1, 6, 1, 4, 5, 1, 2, 5, 2, 1, 1, 2, 9, 2, 10, 1, 3, 1, 10, 3, 2, 7, 6, 1, 1, 4, 3, 6, 6, 1, 2, 1, 4, 2, 1, 2, 1, 1, 1, 3, 1, 4, 7, 11, 1, 4, 5, 2, 1, 2, 1, 9, 7, 1, 1, 2, 1, 6, 1, 1, 7, 11, 1, 1, 9, 5, 1, 1, 1, 4, 2, 1, 1, 4, 6, 2, 3, 1, 1, 1, 2, 1, 9, 1, 7, 1, 7, 1, 1, 1, 11, 1, 11, 11, 1, 8, 3, 5, 6, 4, 3, 9, 4, 1, 3, 1, 3, 2, 1, 1, 1, 1, 2, 1, 8, 1, 1, 6, 6, 3, 1, 8, 7, 2, 1, 2, 7, 6, 4, 3, 6, 1, 6, 3, 3, 2, 9, 9, 5, 2, 1, 2, 1, 9, 8, 8, 3, 7, 1, 5, 1, 2, 3, 1, 5, 2, 7, 8, 5, 1, 1, 2, 1, 1, 4, 3, 3, 2, 6, 2, 2, 1, 3, 4, 1, 2, 8, 2, 1, 4, 1, 2, 1, 2, 4, 1, 3, 1, 1, 1, 10, 1, 1, 2, 5, 11, 4, 1, 1, 1, 4, 3, 7, 1, 6, 8, 1, 3, 5, 1, 4, 1, 7, 8, 1, 4, 1, 2, 2, 7, 3, 1, 9, 11, 7, 1, 9, 4, 5, 2, 1, 5, 2, 4, 5, 1, 4, 2, 5, 2, 1, 10, 2, 1, 7, 4, 1, 7, 11, 5, 2, 11, 7, 6, 2, 1, 11, 3, 1, 5, 1, 1, 4, 10, 4, 1, 2, 1, 4, 11, 3, 1, 1, 1, 7, 1, 3, 1, 1, 7, 10, 6, 3, 6, 3, 9, 1, 3, 4, 7, 4, 1, 1, 1, 5, 7, 4, 5, 1, 6, 1, 4, 4, 8, 9, 1, 1, 2, 1, 10, 3, 1, 2, 1, 2, 3, 6, 2, 9, 1, 1, 6, 2, 3, 5, 2, 10, 5, 4, 10, 5, 2, 1, 5, 2, 1, 4, 4, 1, 2, 1, 1, 1, 9, 3, 3, 4, 2, 6, 7, 1, 1, 8, 3, 11, 1, 1, 2, 3, 8, 7, 11, 1, 1, 9, 3, 2, 2, 9, 3, 1, 8, 3, 7, 2, 4, 4, 1, 1, 5, 1, 1, 1, 2, 3, 10, 1, 11, 5, 3, 1, 1, 7, 9, 1, 1, 3, 5, 7, 5, 1, 5, 1, 2, 1, 11, 2, 1, 3, 3, 1, 1, 1, 2, 7, 9, 9, 5, 1, 4, 3, 5, 5, 8, 2, 1, 1, 2, 1, 2, 5, 4, 3, 3, 2, 4, 2, 4, 1, 8, 1, 2, 8, 3, 1, 8, 1, 1, 3, 2, 1, 1, 7, 1, 8, 1, 1, 1, 1, 2, 3, 6, 7, 1, 4, 4, 9, 6, 3, 4, 7, 6, 10, 1, 5, 6, 2, 3, 2, 3, 2, 11, 5, 3, 3, 6, 2, 1, 8, 5, 1, 8, 7, 2, 10, 1, 3, 1, 9, 2, 1, 10, 3, 3, 1, 1, 1, 1, 1, 8, 7, 3, 3, 1, 3, 4, 2, 8, 5, 6, 1, 10, 7, 4, 8, 1, 1, 1, 2, 3, 10, 2, 3, 3, 5, 3, 2, 3, 3, 5, 2, 2, 7, 1, 2, 6, 1, 1, 6, 1, 8, 7, 5, 10, 3, 9, 6, 3, 3, 11, 10, 4, 10, 5, 2, 1, 4, 1, 2, 6, 6, 3, 4, 1, 1, 2, 2, 1, 2, 1, 1, 3, 1, 1, 3]
        XCTAssertEqual(degrees, expectedDegrees)
        var totals: [Int: Int] = [:]
        for degree in degrees {
            totals[degree, default: 0] += 1
        }
        let sortedDegrees = Array(totals)
            .sorted { $0.key < $1.key }
            .map { $0.value }
        XCTAssertEqual(sortedDegrees, [328, 151, 116, 77, 71, 54, 52, 55, 33, 33, 30])
        // Nominal values for 1000 samples: [331, 166, 110, 83, 66, 55, 47, 41, 37, 33, 30]
    }

    func testFragmentChooser() {
        let message = makeMessage(len: 1024)
        let checksum = CRC32.checksum(message)
        let fragmentLen = FountainEncoder.findNominalFragmentLength(messageLen: message.count, minFragmentLen: 10, maxFragmentLen: 100)
        let fragments = FountainEncoder.partitionMessage(message, fragmentLen: fragmentLen)
        let fragmentChooser = FragmentChooser(seqLen: fragments.count, checksum: checksum)
        let fragmentIndexes = (1...50).map { nonce -> [Int] in
            Array(fragmentChooser.chooseFragments(at: UInt32(nonce))).sorted()
        }
        //print(partIndexes)

        // The first `seqLen` parts are the "simple" fixed-rate fragments, not mixed with any
        // others. This means that if you only generate the first `seqLen` parts,
        // you have all the fragments you need to decode the message.
        let expectedFragmentIndexes = [
            // Fixed-rate parts:
            [0],
            [1],
            [2],
            [3],
            [4],
            [5],
            [6],
            [7],
            [8],
            [9],
            [10],
            
            // Rateless parts:
            [9],
            [2, 5, 6, 8, 9, 10],
            [8],
            [1, 5],
            [1],
            [0, 2, 4, 5, 8, 10],
            [5],
            [2],
            [2],
            [0, 1, 3, 4, 5, 7, 9, 10],
            [0, 1, 2, 3, 5, 6, 8, 9, 10],
            [0, 2, 4, 5, 7, 8, 9, 10],
            [3, 5],
            [4],
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            [0, 1, 3, 4, 5, 6, 7, 9, 10],
            [6],
            [5, 6],
            [7],
            [4, 9, 10],
            [5],
            [10],
            [1, 3, 4, 5],
            [6, 8],
            [9],
            [4, 5, 6, 8],
            [4],
            [0, 10],
            [2, 5, 7, 10],
            [4],
            [0, 2, 4, 6, 7, 10],
            [9],
            [1],
            [3, 6],
            [3, 8],
            [1, 2, 6, 9],
            [0, 2, 4, 5, 6, 7, 9],
            [0, 4],
            [9]
        ]
        XCTAssertEqual(fragmentIndexes, expectedFragmentIndexes)
    }

    func testXOR() {
        let rng = Xoshiro256(string: "Wolf")
        let data1 = rng.nextData(count: 10)
        XCTAssertEqual(data1.hex, "916ec65cf77cadf55cd7")
        let data2 = rng.nextData(count: 10)
        XCTAssertEqual(data2.hex, "f9cda1a1030026ddd42e")
        var data3 = data1
        data2.xor(into: &data3)
        XCTAssertEqual(data3.hex, "68a367fdf47c8b2888f9")
        data1.xor(into: &data3)
        XCTAssertEqual(data3, data2)
    }

    func testEncoder() {
        let message = makeMessage(len: 256)
        let encoder = FountainEncoder(message: message, maxFragmentLen: 30)
        let parts = (0 ..< 20).map { _ in encoder.nextPart().description }
        let expectedParts = [
            "seqNum:1, seqLen:9, messageLen:256, checksum:23570951, data:916ec65cf77cadf55cd7f9cda1a1030026ddd42e905b77adc36e4f2d3c",
            "seqNum:2, seqLen:9, messageLen:256, checksum:23570951, data:cba44f7f04f2de44f42d84c374a0e149136f25b01852545961d55f7f7a",
            "seqNum:3, seqLen:9, messageLen:256, checksum:23570951, data:8cde6d0e2ec43f3b2dcb644a2209e8c9e34af5c4747984a5e873c9cf5f",
            "seqNum:4, seqLen:9, messageLen:256, checksum:23570951, data:965e25ee29039fdf8ca74f1c769fc07eb7ebaec46e0695aea6cbd60b3e",
            "seqNum:5, seqLen:9, messageLen:256, checksum:23570951, data:c4bbff1b9ffe8a9e7240129377b9d3711ed38d412fbb4442256f1e6f59",
            "seqNum:6, seqLen:9, messageLen:256, checksum:23570951, data:5e0fc57fed451fb0a0101fb76b1fb1e1b88cfdfdaa946294a47de8fff1",
            "seqNum:7, seqLen:9, messageLen:256, checksum:23570951, data:73f021c0e6f65b05c0a494e50791270a0050a73ae69b6725505a2ec8a5",
            "seqNum:8, seqLen:9, messageLen:256, checksum:23570951, data:791457c9876dd34aadd192a53aa0dc66b556c0c215c7ceb8248b717c22",
            "seqNum:9, seqLen:9, messageLen:256, checksum:23570951, data:951e65305b56a3706e3e86eb01c803bbf915d80edcd64d4d0000000000",
            "seqNum:10, seqLen:9, messageLen:256, checksum:23570951, data:330f0f33a05eead4f331df229871bee733b50de71afd2e5a79f196de09",
            "seqNum:11, seqLen:9, messageLen:256, checksum:23570951, data:3b205ce5e52d8c24a52cffa34c564fa1af3fdffcd349dc4258ee4ee828",
            "seqNum:12, seqLen:9, messageLen:256, checksum:23570951, data:dd7bf725ea6c16d531b5f03254783803048ca08b87148daacd1cd7a006",
            "seqNum:13, seqLen:9, messageLen:256, checksum:23570951, data:760be7ad1c6187902bbc04f539b9ee5eb8ea6833222edea36031306c01",
            "seqNum:14, seqLen:9, messageLen:256, checksum:23570951, data:5bf4031217d2c3254b088fa7553778b5003632f46e21db129416f65b55",
            "seqNum:15, seqLen:9, messageLen:256, checksum:23570951, data:73f021c0e6f65b05c0a494e50791270a0050a73ae69b6725505a2ec8a5",
            "seqNum:16, seqLen:9, messageLen:256, checksum:23570951, data:b8546ebfe2048541348910267331c643133f828afec9337c318f71b7df",
            "seqNum:17, seqLen:9, messageLen:256, checksum:23570951, data:23dedeea74e3a0fb052befabefa13e2f80e4315c9dceed4c8630612e64",
            "seqNum:18, seqLen:9, messageLen:256, checksum:23570951, data:d01a8daee769ce34b6b35d3ca0005302724abddae405bdb419c0a6b208",
            "seqNum:19, seqLen:9, messageLen:256, checksum:23570951, data:3171c5dc365766eff25ae47c6f10e7de48cfb8474e050e5fe997a6dc24",
            "seqNum:20, seqLen:9, messageLen:256, checksum:23570951, data:e055c2433562184fa71b4be94f262e200f01c6f74c284b0dc6fae6673f"]
        XCTAssertEqual(parts, expectedParts)
    }

    func testEncoderCBOR() {
        let message = makeMessage(len: 256)
        let encoder = FountainEncoder(message: message, maxFragmentLen: 30)
        let parts = (0 ..< 20).map { _ in encoder.nextPart().cbor.hex }
        let expectedParts = [
            "8501091901001a0167aa07581d916ec65cf77cadf55cd7f9cda1a1030026ddd42e905b77adc36e4f2d3c",
            "8502091901001a0167aa07581dcba44f7f04f2de44f42d84c374a0e149136f25b01852545961d55f7f7a",
            "8503091901001a0167aa07581d8cde6d0e2ec43f3b2dcb644a2209e8c9e34af5c4747984a5e873c9cf5f",
            "8504091901001a0167aa07581d965e25ee29039fdf8ca74f1c769fc07eb7ebaec46e0695aea6cbd60b3e",
            "8505091901001a0167aa07581dc4bbff1b9ffe8a9e7240129377b9d3711ed38d412fbb4442256f1e6f59",
            "8506091901001a0167aa07581d5e0fc57fed451fb0a0101fb76b1fb1e1b88cfdfdaa946294a47de8fff1",
            "8507091901001a0167aa07581d73f021c0e6f65b05c0a494e50791270a0050a73ae69b6725505a2ec8a5",
            "8508091901001a0167aa07581d791457c9876dd34aadd192a53aa0dc66b556c0c215c7ceb8248b717c22",
            "8509091901001a0167aa07581d951e65305b56a3706e3e86eb01c803bbf915d80edcd64d4d0000000000",
            "850a091901001a0167aa07581d330f0f33a05eead4f331df229871bee733b50de71afd2e5a79f196de09",
            "850b091901001a0167aa07581d3b205ce5e52d8c24a52cffa34c564fa1af3fdffcd349dc4258ee4ee828",
            "850c091901001a0167aa07581ddd7bf725ea6c16d531b5f03254783803048ca08b87148daacd1cd7a006",
            "850d091901001a0167aa07581d760be7ad1c6187902bbc04f539b9ee5eb8ea6833222edea36031306c01",
            "850e091901001a0167aa07581d5bf4031217d2c3254b088fa7553778b5003632f46e21db129416f65b55",
            "850f091901001a0167aa07581d73f021c0e6f65b05c0a494e50791270a0050a73ae69b6725505a2ec8a5",
            "8510091901001a0167aa07581db8546ebfe2048541348910267331c643133f828afec9337c318f71b7df",
            "8511091901001a0167aa07581d23dedeea74e3a0fb052befabefa13e2f80e4315c9dceed4c8630612e64",
            "8512091901001a0167aa07581dd01a8daee769ce34b6b35d3ca0005302724abddae405bdb419c0a6b208",
            "8513091901001a0167aa07581d3171c5dc365766eff25ae47c6f10e7de48cfb8474e050e5fe997a6dc24",
            "8514091901001a0167aa07581de055c2433562184fa71b4be94f262e200f01c6f74c284b0dc6fae6673f"
        ]
        XCTAssertEqual(parts, expectedParts)
    }

    func testEncoderIsComplete() {
        let message = makeMessage(len: 256)
        let encoder = FountainEncoder(message: message, maxFragmentLen: 30)
        var generatedPartsCount = 0
        while !encoder.isComplete {
            _ = encoder.nextPart()
            generatedPartsCount += 1
        }
        XCTAssertEqual(encoder.seqLen, generatedPartsCount)
    }

    func testDecoder() {
        let messageSize = 32767
        let maxFragmentLen = 1000

        let message = makeMessage(len: messageSize)
        let encoder = FountainEncoder(message: message, maxFragmentLen: maxFragmentLen, firstSeqNum: 100)
        let decoder = FountainDecoder()
        repeat {
            let part = encoder.nextPart()
            _ = decoder.receivePart(part)
            //print(decoder.estimatedPercentComplete)
        } while decoder.result == nil
        switch decoder.result! {
        case .success(let decodedMessage):
            XCTAssertEqual(decodedMessage, message)
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }

    func testCBOR() throws {
        let part = FountainEncoder.Part(seqNum: 12, seqLen: 8, messageLen: 100, checksum: 0x12345678, data: Data([1,5,3,3,5]))
        let cbor = part.cbor
        XCTAssertEqual(cbor.hex, "850c0818641a12345678450105030305")
        XCTAssertEqual(try! CBOR(cbor).diagnostic(), """
        [
           12,
           8,
           100,
           305419896,
           h'0105030305'
        ]
        """)
        let part2 = try FountainEncoder.Part(cbor: cbor)
        let cbor2 = part2.cbor
        XCTAssertEqual(cbor, cbor2)
    }
}
