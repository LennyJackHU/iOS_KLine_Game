//
//  StockSelectionView.swift
//  KLineSwift
//
//  Created by YiJia Hu on 2025/9/12.
//

import SwiftUI

/// 主视图 - 股票选择界面
struct StockSelectionView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var showConfirmation = false
    @State private var showTrading = false
    @ObservedObject private var ble = BLEManager.shared
    @State private var presentBLEPicker = false
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.2),
                    Color(red: 0.1, green: 0.15, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if showTrading {
                // 交易界面
                if let selectedStock = viewModel.selectedStock {
                    TradingView(
                        viewModel: viewModel,
                        selectedStock: selectedStock,
                        onExitTrading: {
                            print("=== Exiting to stock selection ===")
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showTrading = false
                                showConfirmation = false
                            }
                        }
                    )
                    .onAppear {
                        print("=== Trading view appeared ===")
                    }
                }
            } else if !showConfirmation {
                // 股票选择界面
                ScrollView {
                    VStack(spacing: 24) {
                        // 标题区域
                        VStack(spacing: 8) {
                            Text("选择交易标的")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("点击选择您要挑战的加密货币")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 20)
                        
                        // 股票网格
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.stocks, id: \.symbol) { stock in
                                StockCardView(stock: stock) {
                                    print("=== Stock Selected in View: \(stock.symbol) ===")
                                    viewModel.selectStock(stock)
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showConfirmation = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
                .onAppear {
                    // 提前触发蓝牙扫描/连接
                    BLEManager.shared.bootstrapAutoConnect()
                    // 首次允许连接弹窗：若未保存设备，首屏出现时弹一次
                    if BLEManager.shared.connectedPeripheralName == nil, BLEManager.shared.discoveredDevices.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            presentBLEPicker = true
                        }
                    }
                }
                .sheet(isPresented: Binding(get: { presentBLEPicker || ble.shouldPresentPicker }, set: { v in presentBLEPicker = v; if !v { ble.shouldPresentPicker = false } })) {
                    BLEDevicePickerSheet()
                }
            } else {
                // 选择确认界面
                StockConfirmationView(
                    selectedStock: viewModel.selectedStock,
                    onConfirm: {
                        print("=== Stock Confirmed, proceed to trading ===")
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showTrading = true
                        }
                    },
                    onCancel: {
                        print("=== Selection cancelled ===")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showConfirmation = false
                        }
                    }
                )
            }
        }
    }
}

/// 股票卡片视图 - 使用简单 SwiftUI 按钮（参考触摸测试成功方案）
struct StockCardView: View {
    let stock: StockData
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            print("=== StockCard Button Tapped: \(stock.symbol) ===")
            onTap()
        }) {
            VStack(spacing: 12) {
                // 加密货币图标
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 50, height: 50)
                    
                    Text(String(stock.symbol.prefix(3)))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // 股票信息
                VStack(spacing: 4) {
                    Text(stock.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(stock.name)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                
                // 最新价格
                if let lastCandle = stock.candles.last {
                    Text("$\(String(format: "%.2f", lastCandle.close))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .frame(minHeight: 140)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isPressed ? 0.2 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

/// 股票选择确认视图
struct StockConfirmationView: View {
    let selectedStock: StockData?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            // 标题
            Text("确认选择")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if let stock = selectedStock {
                // 选中的股票信息
                VStack(spacing: 20) {
                    // 大图标
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 100, height: 100)
                        
                        Text(String(stock.symbol.prefix(3)))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // 股票详情
                    VStack(spacing: 8) {
                        Text(stock.symbol)
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text(stock.name)
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                        
                        if let lastCandle = stock.candles.last {
                            Text("$\(String(format: "%.2f", lastCandle.close))")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    
                    // 说明文字
                    Text("您将挑战 \(stock.name) 的历史K线数据")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // 操作按钮
            HStack(spacing: 20) {
                // 取消按钮
                Button(action: {
                    print("=== Cancel button tapped ===")
                    onCancel()
                }) {
                    Text("重新选择")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                
                // 确认按钮
                Button(action: {
                    print("=== Confirm button tapped ===")
                    onConfirm()
                }) {
                    Text("开始挑战")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange, Color.red]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
        }
        .padding(24)
    }
}

#Preview {
    StockSelectionView(viewModel: GameViewModel())
}
