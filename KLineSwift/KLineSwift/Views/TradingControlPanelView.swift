//
//  TradingControlPanelView.swift
//  KLineSwift
//
//  交易控制面板 - 包含做多/做空、杠杆调节、保证金等控制
//

import SwiftUI

/// 交易控制面板 - 右侧控制区域
struct TradingControlPanelView: View {
    let stock: StockData
    @ObservedObject var viewModel: GameViewModel
    let currentPrice: Double          // 新增
    let dailyChangePercent: Double
    let onExitTrading: () -> Void
    
    // 交易状态
    @State private var tradeDirection: TradeDirection = .long
    @State private var leverage: Int = 1
    @State private var margin: Int = 5
    @State private var isPositionOpen = false
    @State private var currentPnL: Double = 0.0
    @State private var entryPrice: Double = 0.0
    @State private var showCoinInsertion = false
    @State private var showSettlement = false
    @State private var tradeResult: TradeResult?
    @State private var positionStartTime: Date?
    

    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 标题栏
                headerSection
                
                if !isPositionOpen {
                    // 开仓控制区域
                    openPositionSection
                } else {
                    // 持仓监控区域
                    positionMonitorSection
                }
                
                Spacer(minLength: 20)
                
                // 退出按钮
                exitButton
            }
            .padding(16)
        }
        .background(Color(red: 0.08, green: 0.1, blue: 0.15))
        .overlay(
            // 覆盖层 - 投币界面和结算页面
            Group {
                if showCoinInsertion {
                    CoinInsertionView(
                        requiredCoins: margin,
                        onCoinsInserted: { coins in
                            showCoinInsertion = false
                            confirmOpenPosition()
                        },
                        onCancel: {
                            showCoinInsertion = false
                        }
                    )
                }
                
                if showSettlement, let result = tradeResult {
                    SettlementView(
                        tradeResult: result,
                        onConfirm: {
                            showSettlement = false
                            tradeResult = nil
                        }
                    )
                }
            }
        )
    }
    
    // MARK: - 子组件
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("交易控制")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(stock.symbol)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    private var openPositionSection: some View {
        VStack(spacing: 16) {
            // 做多/做空选择
            directionSelector
            
            // 杠杆选择
            leverageSelector
            
            // 保证金选择
            marginSelector
            
            // 开仓按钮
            openPositionButton
        }
    }
    
    private var positionMonitorSection: some View {
        VStack(spacing: 16) {
            // 持仓信息
            positionInfo
            
            // 浮动盈亏
            pnlDisplay
            
            // 平仓按钮
            closePositionButton
        }
    }
    
    private var directionSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("交易方向")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 12) {
                // 做多按钮
                Button(action: {
                    print("=== Long selected ===")
                    tradeDirection = .long
                }) {
                    Text("做多 📈")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(tradeDirection == .long ? .white : .white.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(tradeDirection == .long ? Color.green : Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                
                // 做空按钮
                Button(action: {
                    print("=== Short selected ===")
                    tradeDirection = .short
                }) {
                    Text("做空 📉")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(tradeDirection == .short ? .white : .white.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(tradeDirection == .short ? Color.red : Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var leverageSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("杠杆倍数")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 8) {
                ForEach([1, 5, 10], id: \.self) { leverageValue in
                    Button(action: {
                        print("=== Leverage \(leverageValue)x selected ===")
                        leverage = leverageValue
                    }) {
                        Text("\(leverageValue)x")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(leverage == leverageValue ? .white : .white.opacity(0.7))
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(leverage == leverageValue ? Color.orange : Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var marginSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("保证金 (游戏币)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 8) {
                ForEach([5, 10], id: \.self) { marginValue in
                    Button(action: {
                        print("=== Margin \(marginValue) selected ===")
                        margin = marginValue
                    }) {
                        Text("\(marginValue) 币")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(margin == marginValue ? .white : .white.opacity(0.7))
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(margin == marginValue ? Color.blue : Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var openPositionButton: some View {
        Button(action: {
            print("=== Open position requested: \(tradeDirection) \(leverage)x margin:\(margin) ===")
            // 显示投币界面
            showCoinInsertion = true
        }) {
            VStack(spacing: 4) {
                Text("开仓交易")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("\(tradeDirection == .long ? "做多" : "做空") \(leverage)x")
                    .font(.caption)
                    .opacity(0.9)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        tradeDirection == .long ? .green : .red,
                        tradeDirection == .long ? .green.opacity(0.7) : .red.opacity(0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
    
    private var positionInfo: some View {
        VStack(spacing: 8) {
            Text("当前持仓")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("方向")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(tradeDirection == .long ? "做多 📈" : "做空 📉")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(tradeDirection == .long ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("杠杆")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(leverage)x")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("开仓价")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("$\(String(format: "%.4f", entryPrice))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("保证金")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(margin) 币")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前变价")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    let Diff = currentPrice - entryPrice
                    Text("$\(String(format: "%.4f", Diff))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Diff >= 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("状态")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("正常")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var pnlDisplay: some View {
        VStack(spacing: 8) {
            Text("浮动盈亏")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            VStack(spacing: 4) {
                // 盈亏金额
                let Difff = tradeDirection == .long ? (currentPrice - entryPrice) : (entryPrice - currentPrice)
                Text(Difff >= 0 ? "+\(String(format: "%.4f", Difff))" : "\(String(format: "%.4f", Difff))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(tradeDirection == .long ? .green : .red)
                
                // 盈亏百分比
                let pnlPercent = (Difff / entryPrice) * 100
                Text("\(pnlPercent >= 0 ? "+" : "")\(String(format: "%.3f", pnlPercent))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(tradeDirection == .long ? .green : .red)
            }
            
            Text("游戏币")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(currentPnL >= 0 ? Color.green : Color.red, lineWidth: 1)
                )
        )
    }
    
    private var closePositionButton: some View {
        Button(action: {
            print("=== Close position ===")
            closePosition()
        }) {
            Text("平仓")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var exitButton: some View {
        Button(action: {
            print("=== Exit trading tapped ===")
            onExitTrading()
        }) {
            Text("退出交易")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 交易逻辑
    
    private func confirmOpenPosition() {
        // 投币完成后确认开仓
        print("=== Confirmed open position: \(tradeDirection) \(leverage)x margin:\(margin) ===")
        openPosition()
    }
    
    private func openPosition() {
        // 使用当前实时价格作为开仓价格
        entryPrice = currentPrice > 0 ? currentPrice : (stock.candles.last?.close ?? 100.0)
        isPositionOpen = true
        positionStartTime = Date() // 记录开仓时间
        
        // 开始模拟价格变动和盈亏计算
        startPnLSimulation()
        
        print("=== Position opened at price: \(entryPrice) ===")
    }
    
    private func closePosition() {
        // 计算交易结果
        let exitPrice = currentPrice // 使用当前实时价格作为平仓价格
        let finalPnL = calculateFinalPnL(entryPrice: entryPrice, exitPrice: exitPrice)
        
        // 创建交易结果
        tradeResult = TradeResult(
            symbol: stock.symbol,
            direction: tradeDirection,
            leverage: leverage,
            margin: margin,
            entryPrice: entryPrice,
            exitPrice: exitPrice,
            pnl: finalPnL
        )
        
        // 显示结算页面
        showSettlement = true
        
        // 重置交易状态
        isPositionOpen = false
        currentPnL = 0.0
        entryPrice = 0.0
        positionStartTime = nil // 重置开仓时间
        
        print("=== Position closed: Entry:\(entryPrice) Exit:\(exitPrice) PnL:\(finalPnL) ===")
    }
    
    // MARK: - 盈亏计算
    
    private func calculateFinalPnL(entryPrice: Double, exitPrice: Double) -> Double {
        let priceChange = exitPrice - entryPrice
        let direction: Double = tradeDirection == .long ? 1.0 : -1.0
        let pnlPercent = (priceChange / entryPrice) * direction
        let finalPnL = Double(margin) * Double(leverage) * pnlPercent
        return finalPnL
    }
    
    private func startPnLSimulation() {
        // 基于实时价格计算盈亏
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if !self.isPositionOpen {
                timer.invalidate()
                return
            }
            
            // 使用实时价格计算当前盈亏
            self.currentPnL = self.calculateCurrentPnL()
        }
        
    }
    
    private func calculateCurrentPnL() -> Double {
        guard entryPrice > 0 else { return 0.0 }
        
        let currentMarketPrice = currentPrice > 0 ? currentPrice : (stock.candles.last?.close ?? entryPrice)
        let priceChange = currentMarketPrice - entryPrice
        let direction: Double = tradeDirection == .long ? 1.0 : -1.0
        let pnlPercent = (priceChange / entryPrice) * direction
        let realTimePnL = Double(margin) * Double(leverage) * pnlPercent
        
        return realTimePnL
    }
}

// MARK: - 辅助枚举

enum TradeDirection {
    case long, short
}

#Preview {
    TradingControlPanelView(
        stock: StockData(symbol: "BTCUSDT", name: "比特币", candles: []),
        viewModel: GameViewModel(),
        currentPrice: 110000,
        dailyChangePercent: 2.35,
        onExitTrading: { }
    )
    .frame(width: 300, height: 600)
    .background(Color(red: 0.08, green: 0.1, blue: 0.15))
}
