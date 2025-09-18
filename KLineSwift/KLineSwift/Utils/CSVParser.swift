//
//  CSVParser.swift
//  KLineSwift
//
//  CSV 数据解析工具
//

import Foundation

class CSVParser {
    
    /// 从Bundle中加载CSV文件并解析为CandleData数组
    static func loadCandleData(from fileName: String) -> [CandleData] {
        guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            print("=== CSV Parser Error: Cannot find file \(fileName) in bundle ===")
            return []
        }
        
        guard let content = try? String(contentsOf: fileURL) else {
            print("=== CSV Parser Error: Cannot read content from \(fileName) ===")
            return []
        }
        
        return parseCSVContent(content)
    }
    
    /// 解析CSV内容为CandleData数组
    private static func parseCSVContent(_ content: String) -> [CandleData] {
        let lines = content.components(separatedBy: .newlines)
        var candles: [CandleData] = []
        
        // 跳过标题行，从第2行开始
        for (index, line) in lines.enumerated() {
            if index == 0 || line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            
            let columns = line.components(separatedBy: ",")
            if columns.count >= 6 {
                if let timestamp = Double(columns[0]),
                   let open = Double(columns[1]),
                   let high = Double(columns[2]),
                   let low = Double(columns[3]),
                   let close = Double(columns[4]),
                   let volume = Double(columns[5]) {
                    
                    let candle = CandleData(
                        timestamp: Date(timeIntervalSince1970: timestamp),
                        open: open,
                        high: high,
                        low: low,
                        close: close,
                        volume: volume
                    )
                    candles.append(candle)
                }
            }
        }
        
        print("=== CSV Parser: Successfully loaded \(candles.count) candles ===")
        return candles
    }
    
    /// 获取所有可用的CSV文件名
    static func getAvailableCSVFiles() -> [String] {
        let fileManager = FileManager.default
        guard let bundlePath = Bundle.main.resourcePath else {
            return []
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: bundlePath)
            let csvFiles = files.filter { $0.hasSuffix(".csv") }
            print("=== CSV Parser: Found \(csvFiles.count) CSV files ===")
            return csvFiles
        } catch {
            print("=== CSV Parser Error: Cannot list bundle contents: \(error) ===")
            return []
        }
    }
    
    /// 从文件名提取币种符号
    static func extractSymbol(from fileName: String) -> String {
        let baseName = fileName.replacingOccurrences(of: ".csv", with: "")
        if let underscoreIndex = baseName.firstIndex(of: "_") {
            return String(baseName[..<underscoreIndex])
        }
        return baseName
    }
    
    /// 从文件名提取中文名称
    static func extractChineseName(from fileName: String) -> String {
        let baseName = fileName.replacingOccurrences(of: ".csv", with: "")
        if let underscoreIndex = baseName.firstIndex(of: "_") {
            let afterUnderscore = baseName[baseName.index(after: underscoreIndex)...]
            return String(afterUnderscore)
        }
        return baseName
    }
}