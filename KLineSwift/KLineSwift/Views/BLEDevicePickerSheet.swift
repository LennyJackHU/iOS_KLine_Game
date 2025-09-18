//
//  BLEDevicePickerSheet.swift
//  KLineSwift
//

import SwiftUI
import CoreBluetooth

struct BLEDevicePickerSheet: View {
    @ObservedObject var ble = BLEManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("可用设备")) {
                    ForEach(ble.discoveredDevices, id: \.identifier) { device in
                        Button(action: {
                            ble.stopScan()
                            ble.connect(device)
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name ?? "未命名设备")
                                        .foregroundColor(.primary)
                                    Text(device.identifier.uuidString)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    if let saved = ble.connectedPeripheralName, saved == device.name {
                                        Text("当前连接")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("连接投币器")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(ble.isScanning ? "扫描中" : "扫描") {
                        if ble.isScanning { ble.stopScan() } else { ble.startScan() }
                    }
                    .disabled(!ble.isPoweredOn)
                }
            }
            .onAppear {
                if ble.isPoweredOn { ble.startScan() }
            }
            .onDisappear { ble.stopScan() }
        }
    }
}

#Preview {
    BLEDevicePickerSheet()
}


