//
//  BLEManager.swift
//  KLineSwift
//
//  CoreBluetooth central wrapper for ESP32 coin box/dispenser
//

import Foundation
import CoreBluetooth
import Combine
import UIKit

final class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()

    // MARK: - Public published state
    @Published var isPoweredOn: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectedPeripheralName: String? = nil
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var isScanning: Bool = false
    @Published var shouldPresentPicker: Bool = false
    @Published var currentCoinTotal: Int = 0

    // MARK: - ESP32 GATT UUIDs (must match firmware)
    struct UUIDs {
        static let service = CBUUID(string: "8F1D0001-7E08-4E27-9D94-7A2C3B6E10A1")
        static let coinCountNotify = CBUUID(string: "8F1D0002-7E08-4E27-9D94-7A2C3B6E10A1") // notify: uint16 little-endian running total
        static let commandWrite = CBUUID(string: "8F1D0003-7E08-4E27-9D94-7A2C3B6E10A1")   // write: command payload
        static let statusNotify = CBUUID(string: "8F1D0004-7E08-4E27-9D94-7A2C3B6E10A1")   // notify: status/events
    }

    // MARK: - Private CoreBluetooth
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var coinChar: CBCharacteristic?
    private var commandChar: CBCharacteristic?
    private var statusChar: CBCharacteristic?

    private var coinContinuation: CheckedContinuation<Int, Never>?
    private var requiredCoins: Int = 0
    private var latestCoinTotal: Int = 0
    private var coinSessionActive: Bool = false

    private let stateQueue = DispatchQueue(label: "ble.manager.state")
    private var retryTimer: Timer?
    private var pendingReconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5
    private let reconnectIntervalSec: TimeInterval = 3.0

    private let defaults = UserDefaults.standard
    private let savedDeviceKey = "ble.savedPeripheralUUID"
    private var savedPeripheralId: UUID? {
        get {
            if let s = defaults.string(forKey: savedDeviceKey) { return UUID(uuidString: s) }
            return nil
        }
        set {
            if let v = newValue { defaults.set(v.uuidString, forKey: savedDeviceKey) } else { defaults.removeObject(forKey: savedDeviceKey) }
        }
    }

    // MARK: - Init
    private override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: stateQueue)
        NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appEnteredBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    // MARK: - Scanning/Connection
    func startScan() {
        guard central.state == .poweredOn else { return }
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.discoveredDevices.removeAll()
            self.isScanning = true
            self.central.scanForPeripherals(withServices: [UUIDs.service], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }

    func stopScan() {
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.central.stopScan()
            self.isScanning = false
        }
    }

    func connect(_ peripheral: CBPeripheral) {
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.peripheral = peripheral
            peripheral.delegate = self
            self.central.connect(peripheral, options: nil)
            self.savedPeripheralId = peripheral.identifier
        }
    }

    func disconnect() {
        stateQueue.async { [weak self] in
            guard let self, let p = self.peripheral else { return }
            self.central.cancelPeripheralConnection(p)
        }
    }

    // MARK: - Bootstrap and Auto Connect
    func bootstrapAutoConnect() {
        // Called from UI early lifecycle
        if central.state == .poweredOn {
            attemptReconnectIfSaved()
            if !isConnected { startScan() }
        } else {
            // Will auto-trigger when powered on
        }
    }

    private func attemptReconnectIfSaved() {
        guard let savedId = savedPeripheralId else { return }
        let matches = central.retrievePeripherals(withIdentifiers: [savedId])
        if let p = matches.first {
            peripheral = p
            p.delegate = self
            central.connect(p, options: nil)
        } else {
            // fall back to scan
            startScan()
        }
    }

    @objc private func appBecameActive() {
        // Resume reconnect if needed
        if !isConnected { scheduleReconnect() }
    }

    @objc private func appEnteredBackground() {
        // Optional: stop scans to save power
        stopScan()
    }

    // MARK: - High-level coin APIs
    // Async wait until coin total >= required, returns actual total
    func waitForCoins(required: Int) async -> Int {
        requiredCoins = required
        // start a fresh session each time
        latestCoinTotal = 0
        DispatchQueue.main.async { self.currentCoinTotal = 0 }
        coinSessionActive = true
        return await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            self.coinContinuation = continuation
            // Ask firmware to reset/arm counting session
            self.sendCommand(.startCoinSession)
        }
    }

    // For UI to proactively clear displayed total before a session begins
    func resetDisplayedCoinCount() {
        latestCoinTotal = 0
        DispatchQueue.main.async { self.currentCoinTotal = 0 }
    }

    // Payout request: amount in integer coins; single denomination hardware
    // Returns tuple (dispensedCount, 0, 0) to keep signature stable
    func requestPayout(amount: Int) async -> (Int, Int, Int) {
        return await withCheckedContinuation { (continuation: CheckedContinuation<(Int, Int, Int), Never>) in
            self.pendingPayoutContinuation = continuation
            self.sendCommand(.payout(amount: amount))
        }
    }

    // MARK: - Command protocol
    private enum OutCommand {
        case startCoinSession
        case payout(amount: Int)
    }

    private func sendCommand(_ cmd: OutCommand) {
        guard let p = peripheral, let commandChar else { return }
        let data: Data
        switch cmd {
        case .startCoinSession:
            data = Data([0x01, 0x00, 0x00, 0x00]) // CMD=1, no payload
        case .payout(let amount):
            var amtLE = UInt16(clamping: amount).littleEndian
            var buf = Data([0x02])
            withUnsafeBytes(of: &amtLE) { buf.append(contentsOf: $0) } // 2 bytes count
            data = buf
        }
        p.writeValue(data, for: commandChar, type: .withResponse)
    }

    // MARK: - Incoming status handling
    private var pendingPayoutContinuation: CheckedContinuation<(Int, Int, Int), Never>?
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.isPoweredOn = (central.state == .poweredOn)
        }
        if central.state == .poweredOn {
            // Auto attempt reconnect
            attemptReconnectIfSaved()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            DispatchQueue.main.async {
                self.discoveredDevices.append(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([UUIDs.service])
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectedPeripheralName = peripheral.name
            self.pendingReconnectAttempts = 0
            self.retryTimer?.invalidate()
            self.shouldPresentPicker = false
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedPeripheralName = nil
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        coinContinuation = nil
        pendingPayoutContinuation = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedPeripheralName = nil
            self.scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        guard pendingReconnectAttempts < maxReconnectAttempts else {
            // Show picker to user to reselect device
            self.shouldPresentPicker = true
            return
        }
        pendingReconnectAttempts += 1
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: reconnectIntervalSec, repeats: false) { [weak self] _ in
            guard let self else { return }
            if let p = self.peripheral {
                self.central.connect(p, options: nil)
            } else {
                self.attemptReconnectIfSaved()
            }
            if !self.isConnected { self.scheduleReconnect() }
        }
        RunLoop.main.add(retryTimer!, forMode: .common)
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        peripheral.services?.forEach { svc in
            if svc.uuid == UUIDs.service {
                peripheral.discoverCharacteristics([UUIDs.coinCountNotify, UUIDs.commandWrite, UUIDs.statusNotify], for: svc)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }
        service.characteristics?.forEach { ch in
            switch ch.uuid {
            case UUIDs.coinCountNotify:
                coinChar = ch
                peripheral.setNotifyValue(true, for: ch)
            case UUIDs.commandWrite:
                commandChar = ch
            case UUIDs.statusNotify:
                statusChar = ch
                peripheral.setNotifyValue(true, for: ch)
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        if characteristic.uuid == UUIDs.coinCountNotify {
            // Expect 2 bytes little-endian uint16 = total inserted
            if data.count >= 2 {
                let total = Int(UInt16(littleEndian: data.withUnsafeBytes { $0.load(as: UInt16.self) }))
                latestCoinTotal = total
                DispatchQueue.main.async {
                    self.currentCoinTotal = total
                }
                if coinSessionActive, total >= requiredCoins, let cont = coinContinuation {
                    coinSessionActive = false
                    coinContinuation = nil
                    DispatchQueue.main.async { cont.resume(returning: total) }
                }
            }
        } else if characteristic.uuid == UUIDs.statusNotify {
            // Status/event framing: [eventId, payload...]
            if let eventId = data.first {
                switch eventId {
                case 0x10: // payout done, payload: dispensedCount u16 LE
                    if data.count >= 3, let cont = pendingPayoutContinuation {
                        let countLE: UInt16 = data.subdata(in: 1..<(3)).withUnsafeBytes { $0.load(as: UInt16.self) }
                        let dispensed = Int(UInt16(littleEndian: countLE))
                        pendingPayoutContinuation = nil
                        DispatchQueue.main.async { cont.resume(returning: (dispensed, 0, 0)) }
                    }
                default:
                    break
                }
            }
        }
    }
}


