//
//  StockModels.swift
//  KLineSwift
//
//  Created by YiJia Hu on 2025/9/12.
//

import Foundation

/// K线数据模型
struct CandleData: Identifiable, Codable {
    var id: String { "\(time)" }
    let time: Double
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    
    /// 转换为 LightweightCharts 的 BarData 格式
    func toBarData() -> BarData {
        return BarData(
            time: .utc(timestamp: time),
            open: open,
            high: high,
            low: low,
            close: close
        )
    }
    
    /// 转换为成交量数据格式
    func toHistogramData() -> HistogramData {
        let color = close >= open ? "#26a69a" : "#ef5350"
        return HistogramData(
            time: .utc(timestamp: time),
            value: volume,
            color: color
        )
    }
    
    /// 转换为线性数据格式（用于移动平均线）
    func toLineData(value: Double) -> LineData {
        return LineData(
            time: .utc(timestamp: time),
            value: value
        )
    }
    
    /// 将模型转换为可用于图表的JSON字符串（向后兼容）
    func toJSON() -> String {
        let dict: [String: Any] = [
            "time": time,
            "open": open,
            "high": high,
            "low": low,
            "close": close,
            "volume": volume
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
}

/// 股票数据模型
struct StockData: Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let candles: [CandleData]
    
    /// 从特定索引获取历史数据的方法
    func getHistoricalData(fromIndex: Int, length: Int) -> [CandleData] {
        guard fromIndex >= 0 && fromIndex < candles.count else { return [] }
        
        let endIndex = min(fromIndex + length, candles.count)
        return Array(candles[fromIndex..<endIndex])
    }
    
    /// 随机选取一段历史数据
    func getRandomSegment(length: Int) -> (data: [CandleData], startIndex: Int) {
        guard candles.count > length else {
            return (candles, 0)
        }
        
        let maxStartIndex = candles.count - length
        let startIndex = Int.random(in: 0...maxStartIndex)
        return (getHistoricalData(fromIndex: startIndex, length: length), startIndex)
    }
    
    /// 转换为 BarData 数组
    func toBarDataArray() -> [BarData] {
        return candles.map { $0.toBarData() }
    }
    
    /// 转换为成交量数据数组
    func toVolumeDataArray() -> [HistogramData] {
        return candles.map { $0.toHistogramData() }
    }
}

// MARK: - CandleData 数组扩展
extension Array where Element == CandleData {
    /// 转换为 BarData 数组
    func toBarDataArray() -> [BarData] {
        return map { $0.toBarData() }
    }
    
    /// 转换为成交量数据数组
    func toVolumeDataArray() -> [HistogramData] {
        return map { $0.toHistogramData() }
    }
    
    /// 计算移动平均线数据
    func calculateMA(period: Int) -> [LineData] {
        guard count >= period else { return [] }
        
        var result: [LineData] = []
        
        for i in period-1..<count {
            let subset = self[(i-(period-1))...i]
            let maValue = subset.reduce(0.0) { $0 + $1.close } / Double(subset.count)
            
            result.append(LineData(
                time: .utc(timestamp: self[i].time),
                value: maValue
            ))
        }
        
        return result
    }
}
