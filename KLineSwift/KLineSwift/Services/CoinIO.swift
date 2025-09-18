//
//  CoinIO.swift
//  KLineSwift
//
//  Static interfaces required by app business layer
//

import Foundation

enum CoinBox {
    // Preferred: CoinBox.waitUntil(required: n)
    static func waitUntil(required: Int) async -> Int {
        return await BLEManager.shared.waitForCoins(required: required)
    }

    // Convenience overload to tolerate different call sites
    static func waitUntil(_ required: Int) async -> Int {
        return await waitUntil(required: required)
    }
}

enum CoinDispenser {
    // Returns tuple (ones, fives, tens)
    static func payout(_ amount: Int) async -> (Int, Int, Int) {
        return await BLEManager.shared.requestPayout(amount: amount)
    }
}


