//
//  SettlementView.swift
//  KLineSwift
//
//  交易结算页面 - 显示交易结果和盈亏
//

import SwiftUI

/// 交易结算视图
struct SettlementView: View {
    let tradeResult: TradeResult
    let onConfirm: () -> Void
    
    @State private var animationScale: Double = 0.8
    @State private var showContent: Bool = false
    
    var body: some View {
        ZStack {
            // 半透明黑色背景
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    // 防止误触关闭
                }
            
            // 结算内容卡片
            VStack(spacing: 0) {
                // 标题区域
                headerSection
                
                // 交易详情
                tradeDetailsSection
                
                // 盈亏结果
                pnlResultSection
                
                // 确认按钮
                confirmButton
            }
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.1, green: 0.12, blue: 0.16))
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            )
            .scaleEffect(animationScale)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            // 入场动画
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animationScale = 1.0
                showContent = true
            }
        }
    }
    
    // MARK: - 子组件
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            // 结果图标
            ZStack {
                Circle()
                    .fill(tradeResult.isProfitable ? Color.green : Color.red)
                    .frame(width: 60, height: 60)
                    .shadow(color: tradeResult.isProfitable ? .green.opacity(0.4) : .red.opacity(0.4), radius: 10)
                
                Image(systemName: tradeResult.isProfitable ? "checkmark" : "xmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("交易结算")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(tradeResult.isProfitable ? "盈利！" : "亏损")
                .font(.headline)
                .foregroundColor(tradeResult.isProfitable ? .green : .red)
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    private var tradeDetailsSection: some View {
        VStack(spacing: 12) {
            // 交易信息
            tradeInfoRow("交易品种", tradeResult.symbol)
            tradeInfoRow("交易方向", tradeResult.direction == .long ? "做多 📈" : "做空 📉")
            tradeInfoRow("杠杆倍数", "\(tradeResult.leverage)x")
            tradeInfoRow("保证金", "\(tradeResult.margin) 游戏币")
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 8)
            
            // 价格信息
            tradeInfoRow("开仓价格", "$\(String(format: "%.4f", tradeResult.entryPrice))")
            tradeInfoRow("平仓价格", "$\(String(format: "%.4f", tradeResult.exitPrice))")
            
            let priceChange = tradeResult.exitPrice - tradeResult.entryPrice
            let priceChangePercent = (priceChange / tradeResult.entryPrice) * 100
            
            HStack {
                Text("价格变动")
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(priceChange >= 0 ? "+" : "")\(String(format: "%.4f", priceChange))")
                        .foregroundColor(priceChange >= 0 ? .green : .red)
                    Text("\(priceChangePercent >= 0 ? "+" : "")\(String(format: "%.2f", priceChangePercent))%")
                        .font(.caption)
                        .foregroundColor(priceChange >= 0 ? .green : .red)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var pnlResultSection: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 8)
            
            // 盈亏结果
            VStack(spacing: 8) {
                Text("最终盈亏")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(tradeResult.pnl >= 0 ? "+" : "")\(String(format: "%.2f", tradeResult.pnl)) 游戏币")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(tradeResult.pnl >= 0 ? .green : .red)
                
                // 盈亏百分比
                let pnlPercent = (tradeResult.pnl / Double(tradeResult.margin)) * 100
                Text("收益率: \(pnlPercent >= 0 ? "+" : "")\(String(format: "%.1f", pnlPercent))%")
                    .font(.subheadline)
                    .foregroundColor(pnlPercent >= 0 ? .green : .red)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var confirmButton: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.2))
            
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animationScale = 0.8
                    showContent = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onConfirm()
                }
            }) {
                Text("确认")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.8))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - 辅助方法
    
    private func tradeInfoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 交易结果数据模型

struct TradeResult {
    let symbol: String
    let direction: TradeDirection
    let leverage: Int
    let margin: Int
    let entryPrice: Double
    let exitPrice: Double
    let pnl: Double
    
    var isProfitable: Bool {
        return pnl > 0
    }
}

// MARK: - 预览

#Preview {
    SettlementView(
        tradeResult: TradeResult(
            symbol: "BTCUSDT",
            direction: .long,
            leverage: 5,
            margin: 10,
            entryPrice: 45280.50,
            exitPrice: 46150.75,
            pnl: 43.5
        )
    ) {
        print("结算确认")
    }
}
