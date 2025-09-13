//
//  GameModels.swift
//  KLineSwift
//
//  Created by YiJia Hu on 2025/9/12.
//

import Foundation

/// 游戏状态枚举
enum GameState {
    case selectingStock    // 选择股票
    case settingParameters // 设置交易参数
    case waitingForCoins   // 等待投币
    case trading          // 交易中
    case settlement       // 结算中
}

/// 交易方向枚举
enum TradeDirection: CaseIterable {
    case long   // 做多
    case short  // 做空
    
    var displayName: String {
        switch self {
        case .long:
            return "做多"
        case .short:
            return "做空"
        }
    }
    
    var color: String {
        switch self {
        case .long:
            return "#26a69a"  // 绿色
        case .short:
            return "#ef5350"  // 红色
        }
    }
}

/// 持仓模型
struct Position {
    let direction: TradeDirection
    let leverage: Int
    let entryPrice: Double
    let quantity: Double
    let entryIndex: Int
    let timestamp: Date = Date()
    
    /// 计算当前盈亏
    func calculatePnL(currentPrice: Double) -> (amount: Double, percentage: Double) {
        let priceChange = currentPrice - entryPrice
        let directionMultiplier: Double = direction == .long ? 1.0 : -1.0
        
        let pnlAmount = priceChange * quantity * directionMultiplier * Double(leverage)
        let pnlPercentage = (priceChange / entryPrice) * directionMultiplier * Double(leverage) * 100
        
        return (pnlAmount, pnlPercentage)
    }
}

/// 交易结果模型
struct TradeResult {
    let position: Position
    let exitPrice: Double
    let exitIndex: Int
    let pnlAmount: Double
    let pnlPercentage: Double
    let duration: Int  // 持仓K线数量
    let timestamp: Date = Date()
    
    var isProfit: Bool {
        return pnlAmount > 0
    }
}

/// 蓝牙连接状态
enum BLEConnectionState {
    case disconnected
    case scanning
    case connecting
    case connected
    case failed(Error)
}

/// 蓝牙通知类型
enum BLENotificationType {
    case coinInserted(count: Int)
    case buttonPressed(buttonId: Int)
    case connectionStateChanged(BLEConnectionState)
    case error(String)
}
