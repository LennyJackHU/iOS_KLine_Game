//
//  BLEStatusIndicator.swift
//  KLineSwift
//

import SwiftUI

struct BLEStatusIndicator: View {
    @ObservedObject var ble = BLEManager.shared
    var tapAction: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ble.isConnected ? Color.green : (ble.isPoweredOn ? Color.orange : Color.red))
                .frame(width: 8, height: 8)
            Text(ble.isConnected ? (ble.connectedPeripheralName ?? "已连接") : (ble.isPoweredOn ? "未连接" : "蓝牙未开"))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .onTapGesture { tapAction?() }
        .accessibilityLabel("BLE 状态")
    }
}

#Preview {
    BLEStatusIndicator()
        .padding()
        .background(Color.gray)
}


