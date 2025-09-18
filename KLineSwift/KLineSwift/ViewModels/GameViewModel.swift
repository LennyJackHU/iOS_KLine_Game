//
//  GameViewModel.swift
//  KLineSwift
//
//  加载真实CSV数据并实现随机起始点选择的游戏视图模型
//

import Foundation
import SwiftUI

// MARK: - Supporting Models

struct StockData: Identifiable, Hashable {
    let id = UUID()
    var symbol: String
    var name: String
    var candles: [CandleData]
    
    // 添加随机起始点相关属性
    var randomStartIndex: Int = 0
    var totalCandles: Int {
        return candles.count
    }
    
    // 获取从起始点到当前显示点的数据
    func getInitialDisplayData(upTo displayIndex: Int) -> [CandleData] {
        let endIndex = min(randomStartIndex + displayIndex, candles.count)
        return Array(candles[0..<endIndex])
    }
    
    // 获取可继续推进的数据
    func getRemainingData(from displayIndex: Int) -> [CandleData] {
        let startIndex = randomStartIndex + displayIndex
        guard startIndex < candles.count else { return [] }
        return Array(candles[startIndex..<candles.count])
    }
}

struct CandleData: Hashable {
    var timestamp: Date  // 改为 Date 类型以匹配视图
    var open: Double
    var high: Double
    var low: Double
    var close: Double
    var volume: Double
    
    // 兼容性计算属性
    var time: Double {
        return timestamp.timeIntervalSince1970
    }
}

// MARK: - GameViewModel 

class GameViewModel: ObservableObject {
    // 可供选择的币种列表
    @Published var stocks: [StockData] = []
    // 当前选中的股票
    @Published var selectedStock: StockData?
    // 当前是否已连接蓝牙（占位）
    @Published var bluetoothConnected: Bool = false

    init() {
        // 加载真实CSV数据
        loadRealHistoricalData()
    }

    /// 选择股票并设置随机起始点
    func selectStock(_ stock: StockData) {
        print("=== GameViewModel: Selecting stock \(stock.symbol) ===")
        
        var selectedStock = stock
        // 设置随机起始点：最早30天后，最晚300天前
        let minStartDay = 30
        let maxStartDay = max(minStartDay + 1, stock.totalCandles - 300)
        let randomStartDay = Int.random(in: minStartDay...maxStartDay)
        selectedStock.randomStartIndex = randomStartDay
        
        print("=== Random start point: Day \(randomStartDay)/\(stock.totalCandles) ===")
        
        DispatchQueue.main.async {
            self.selectedStock = selectedStock
            print("=== GameViewModel: Stock selection completed with random start ===")
        }
    }

    /// 从CSV文件加载真实历史数据
    private func loadRealHistoricalData() {
        let csvFiles = CSVParser.getAvailableCSVFiles()
        var loadedStocks: [StockData] = []
        
        for fileName in csvFiles {
            let symbol = CSVParser.extractSymbol(from: fileName)
            let chineseName = CSVParser.extractChineseName(from: fileName)
            let candles = CSVParser.loadCandleData(from: fileName)
            
            if !candles.isEmpty {
                let stock = StockData(
                    symbol: symbol,
                    name: chineseName,
                    candles: candles
                )
                loadedStocks.append(stock)
                print("=== Loaded \(symbol): \(candles.count) candles ===")
            }
        }
        
        // 如果没有加载到CSV数据，使用备用数据
        if loadedStocks.isEmpty {
            print("=== No CSV data loaded, using fallback mock data ===")
            loadedStocks = createFallbackStocks()
        }
        
        DispatchQueue.main.async {
            self.stocks = loadedStocks
            print("=== GameViewModel: Loaded \(loadedStocks.count) stocks ===")
        }
    }
    
    /// 创建备用模拟数据（如果CSV加载失败）
    private func createFallbackStocks() -> [StockData] {
        let symbols = ["BTCUSDT", "ETHUSDT", "BNBUSDT", "XRPUSDT", "SOLUSDT"]
        return symbols.map { sym in
            StockData(symbol: sym, name: sym.dropLast(4) + " 代币", candles: generateLargeMockData())
        }
    }
    
    /// 生成大量模拟数据（2500根K线）
    private func generateLargeMockData() -> [CandleData] {
        var candles: [CandleData] = []
        let baseTime = Date().addingTimeInterval(-2500 * 24 * 3600) // 2500天前开始
        var currentPrice = 100.0
        
        for i in 0..<2500 {
            let open = currentPrice
            let priceChange = Double.random(in: -5...5)
            let close = max(open + priceChange, 5.0)
            let high = max(open, close) + Double.random(in: 0...3)
            let low = min(open, close) - Double.random(in: 0...2)
            let volume = Double.random(in: 1000...10000)
            
            candles.append(CandleData(
                timestamp: baseTime.addingTimeInterval(Double(i) * 24 * 3600),
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume
            ))
            
            currentPrice = close
        }
        
        return candles
    }
}

