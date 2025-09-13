//
//  GameViewModel.swift
//  KLineSwift
//
//  Created by YiJia Hu on 2025/9/12.
//

import Foundation
import Combine
import SwiftUI

/// 游戏视图模型
class GameViewModel: ObservableObject {
    // MARK: - 公开属性
    
    /// 游戏状态
    @Published var gameState: GameState = .selectingStock
    
    /// 选择的股票
    @Published var selectedStock: StockData?
    
    /// 当前持仓
    @Published var currentPosition: Position?
    
    /// 盈亏金额
    @Published var pnl: Double = 0.0
    
    /// 盈亏百分比
    @Published var pnlPercentage: Double = 0.0
    
    /// 出场价格
    @Published var exitPrice: Double = 0.0
    
    /// 需要硬币数量
    @Published var requiredCoins: Int = 0
    
    /// 已投入硬币数量
    @Published var insertedCoins: Int = 0
    
    /// 显示的K线数据
    @Published var displayedCandles: [CandleData] = []
    
    /// 是否正在吐币
    @Published var isDispensing: Bool = false
    
    /// 是否正在打印
    @Published var isPrinting: Bool = false
    
    /// 可用股票列表
    @Published var availableStocks: [StockData] = []
    
    /// 蓝牙连接状态
    @Published var bluetoothConnected: Bool = false
    
    // MARK: - 私有属性
    
    /// 蓝牙管理器
    private let bleManager: BLEManager
    
    /// 交易参数 - 杠杆
    private var leverage: Int = 1
    
    /// 交易参数 - 方向
    private var direction: TradeDirection = .long
    
    /// 开始索引
    private var startIndex: Int = 0
    
    /// 当前索引
    private var currentIndex: Int = 0
    
    /// 用于存储通知的取消者
    private var cancellables = Set<AnyCancellable>()
    
    /// K线推进计时器
    var advanceTimer: Timer?
    
    // MARK: - 初始化
    
    init(bleManager: BLEManager = BLEManager()) {
        self.bleManager = bleManager
        
        // 订阅蓝牙通知
        bleManager.notificationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleBLENotification(notification)
            }
            .store(in: &cancellables)
        
        // 订阅蓝牙连接状态
        bleManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.bluetoothConnected = (state == .connected)
            }
            .store(in: &cancellables)
        
        // 加载可用股票数据
        loadAvailableStocks()
    }
    
    // MARK: - 便利初始化器（无参数）
    
    convenience init() {
        self.init(bleManager: BLEManager())
    }
    
    // MARK: - 公开方法
    
    /// 加载可用股票数据
    func loadAvailableStocks() {
        // 获取所有可用的股票文件
        let stockFiles = CSVParser.getAvailableStockFiles()
        
        // 解析每个文件
        availableStocks = stockFiles.compactMap { fileName in
            CSVParser.parseStockData(from: fileName)
        }
    }
    
    /// 选择股票
    func selectStock(_ stock: StockData) {
        selectedStock = stock
        gameState = .settingParameters
    }
    
    /// 设置交易参数
    func setTradeParameters(direction: TradeDirection, leverage: Int) {
        self.direction = direction
        self.leverage = leverage
        
        // 计算所需硬币数量（假设杠杆越高需要的硬币越多）
        requiredCoins = leverage
        
        // 进入等待投币状态
        gameState = .waitingForCoins
    }
    
    /// 获取当前交易方向
    func getTradeDirection() -> TradeDirection {
        return direction
    }
    
    /// 获取当前杠杆
    func getLeverage() -> Int {
        return leverage
    }
    
    /// 检查投币
    func checkCoins() {
        bleManager.checkCoinSlot()
    }
    
    /// 模拟投币（仅用于开发测试）
    func simulateInsertCoins() {
        insertedCoins = requiredCoins
        startTrade()
    }
    
    /// 开始交易
    func startTrade() {
        guard let stock = selectedStock else { return }
        
        // 确保有足够的数据量
        guard stock.candles.count >= 150 else {
            print("股票数据不足，无法开始交易")
            return
        }
        
        // 随机选择起始点，保证至少有90天后的数据可用
        let minStartIndex = 0
        let maxStartIndex = stock.candles.count - 150 // 保证至少有150根K线可用
        let startIndex = Int.random(in: minStartIndex...maxStartIndex)
        
        // 初始显示90根K线
        let initialSegmentLength = 90
        let initialData = stock.getHistoricalData(fromIndex: startIndex, length: initialSegmentLength)
        
        displayedCandles = initialData
        self.startIndex = startIndex
        currentIndex = startIndex + initialSegmentLength
        
        // 创建持仓
        let entryPrice = initialData.last!.close
        let quantity = 100.0 // 假设固定购买数量为100
        
        currentPosition = Position(
            direction: direction,
            leverage: leverage,
            entryPrice: entryPrice,
            quantity: quantity,
            entryIndex: currentIndex - 1
        )
        
        // 计算初始盈亏
        calculatePnL(with: entryPrice)
        
        // 切换到交易状态
        gameState = .trading
        
        // 启动K线推进计时器
        startAdvanceTimer()
    }
    
    /// 推进K线
    func advanceCandle() {
        guard let stock = selectedStock, currentIndex < stock.candles.count else {
            // 已经到最后一根K线，结束交易
            settleGame()
            return
        }
        
        // 获取下一根K线
        let newCandle = stock.candles[currentIndex]
        
        // 添加到显示数据中
        displayedCandles.append(newCandle)
        currentIndex += 1
        
        // 计算盈亏
        calculatePnL(with: newCandle.close)
        
        // 如果数据太多，移除最早的数据保持性能
        if displayedCandles.count > 200 {
            displayedCandles.removeFirst()
        }
    }
    
    /// 停止推进计时器
    func stopAdvanceTimer() {
        advanceTimer?.invalidate()
        advanceTimer = nil
    }
    
    /// 启动推进计时器
    func startAdvanceTimer(interval: TimeInterval = 1.0) {
        stopAdvanceTimer()
        
        advanceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceCandle()
        }
    }
    
    /// 结算游戏
    func settleGame() {
        guard let position = currentPosition,
              let exitCandle = displayedCandles.last else {
            return
        }
        
        // 停止计时器
        stopAdvanceTimer()
        
        // 记录出场价格
        exitPrice = exitCandle.close
        
        // 计算最终盈亏
        let finalPnL = position.calculatePnL(currentPrice: exitPrice)
        pnl = finalPnL.amount
        pnlPercentage = finalPnL.percentage
        
        // 创建交易结果
        let tradeResult = TradeResult(
            position: position,
            exitPrice: exitPrice,
            exitIndex: currentIndex - 1,
            pnlAmount: pnl,
            pnlPercentage: pnlPercentage,
            duration: currentIndex - position.entryIndex
        )
        
        // 处理结算逻辑
        handleSettlement(tradeResult: tradeResult)
        
        // 切换到结算状态
        gameState = .settlement
    }
    
    /// 重新开始游戏
    func restartGame() {
        // 重置所有状态
        selectedStock = nil
        currentPosition = nil
        pnl = 0.0
        pnlPercentage = 0.0
        exitPrice = 0.0
        requiredCoins = 0
        insertedCoins = 0
        displayedCandles = []
        isDispensing = false
        isPrinting = false
        
        // 停止计时器
        stopAdvanceTimer()
        
        // 返回选择股票状态
        gameState = .selectingStock
    }
    
    /// 启动蓝牙扫描
    func startBLEScanning() {
        bleManager.startScanning()
    }
    
    /// 断开蓝牙连接
    func disconnectBLE() {
        bleManager.disconnect()
    }
    
    // MARK: - 私有方法
    
    /// 处理蓝牙通知
    private func handleBLENotification(_ notification: BLENotificationType) {
        switch notification {
        case .coinInserted(let count):
            insertedCoins += count
            if insertedCoins >= requiredCoins && gameState == .waitingForCoins {
                startTrade()
            }
            
        case .buttonPressed(let buttonId):
            // 处理按钮按下事件
            handleButtonPressed(buttonId: buttonId)
            
        case .connectionStateChanged(let state):
            // 连接状态已经在初始化时订阅处理
            break
            
        case .error(let message):
            print("蓝牙错误: \(message)")
        }
    }
    
    /// 处理按钮按下事件
    private func handleButtonPressed(buttonId: Int) {
        switch buttonId {
        case 1: // 结算按钮
            if gameState == .trading {
                settleGame()
            }
        case 2: // 重新开始按钮
            if gameState == .settlement {
                restartGame()
            }
        default:
            break
        }
    }
    
    /// 计算盈亏
    private func calculatePnL(with currentPrice: Double) {
        guard let position = currentPosition else { return }
        
        let pnlResult = position.calculatePnL(currentPrice: currentPrice)
        pnl = pnlResult.amount
        pnlPercentage = pnlResult.percentage
    }
    
    /// 处理结算逻辑
    private func handleSettlement(tradeResult: TradeResult) {
        if tradeResult.isProfit {
            // 盈利 - 吐币
            dispenseProfitCoins(profit: tradeResult.pnlAmount)
        } else {
            // 亏损 - 显示结果
            print("交易亏损: $\(tradeResult.pnlAmount)")
        }
        
        // 打印交易结果
        printTradeResult(tradeResult: tradeResult)
    }
    
    /// 分配盈利硬币
    private func dispenseProfitCoins(profit: Double) {
        // 根据盈利金额计算硬币数量（示例：每10美元一个硬币）
        let coinCount = max(1, Int(profit / 10.0))
        
        isDispensing = true
        bleManager.dispenseCoin(count: coinCount)
        
        // 模拟吐币过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isDispensing = false
        }
    }
    
    /// 打印交易结果
    private func printTradeResult(tradeResult: TradeResult) {
        isPrinting = true
        
        let ticketData = generateTicketData(tradeResult: tradeResult)
        bleManager.printTicket(data: ticketData)
        
        // 模拟打印过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.isPrinting = false
        }
    }
    
    /// 生成票据数据
    private func generateTicketData(tradeResult: TradeResult) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return """
        ====== 交易结果 ======
        时间: \(formatter.string(from: tradeResult.timestamp))
        品种: \(selectedStock?.symbol ?? "")
        方向: \(tradeResult.position.direction.displayName)
        杠杆: \(tradeResult.position.leverage)x
        开仓价: $\(tradeResult.position.entryPrice)
        平仓价: $\(tradeResult.exitPrice)
        盈亏: $\(tradeResult.pnlAmount)
        盈亏率: \(tradeResult.pnlPercentage)%
        持仓时长: \(tradeResult.duration) 根K线
        ===================
        """
    }
}
