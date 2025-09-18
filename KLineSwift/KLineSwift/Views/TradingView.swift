//
//  TradingView.swift
//  KLineSwift
//
//  完整的交易界面，包含 LightweightCharts 和交易控制面板
//

import SwiftUI
import WebKit
import LightweightCharts

/// 主交易视图 - 左侧图表 + 右侧控制面板
struct TradingView: View {
    @ObservedObject var viewModel: GameViewModel
    let selectedStock: StockData
    @State private var showExitAlert = false
    let onExitTrading: (() -> Void)?

    // Add @State variables to hold the current price and change percent
    // These will be updated by the ChartContainerView and passed to TradingControlPanelView
    @State private var chartCurrentPrice: Double = 0
    @State private var chartDailyChangePercent: Double = 0
    @State private var showDevicePicker = false

    init(viewModel: GameViewModel, selectedStock: StockData, onExitTrading: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.selectedStock = selectedStock
        self.onExitTrading = onExitTrading
        // Initialize these state variables if needed, or let them update from the chart later
        _chartCurrentPrice = State(initialValue: selectedStock.candles.last?.close ?? 0)
        _chartDailyChangePercent = State(initialValue: (
            (selectedStock.candles.last?.close ?? 0) - (selectedStock.candles.last?.open ?? 0)
        ) / (selectedStock.candles.last?.open ?? 1) * 100)
    }

    var body: some View {
        ZStack {
            // 深色背景
            Color.black.ignoresSafeArea()

            HStack(spacing: 0) {
                // 左侧：图表区域 (70%)
                ChartContainerView(
                    stock: selectedStock,
                    onCurrentPriceUpdate: { price, _, percent in // Capture price and percent
                        self.chartCurrentPrice = price
                        self.chartDailyChangePercent = percent
                    }
                )
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.05, green: 0.05, blue: 0.1))

                // 右侧：交易控制面板 (30%)
                TradingControlPanelView(
                    stock: selectedStock,
                    viewModel: viewModel,
                    currentPrice: chartCurrentPrice,        // <-- Pass the state here
                    dailyChangePercent: chartDailyChangePercent, // <-- Pass the state here
                    onExitTrading: {
                        showExitAlert = true
                    }
                )
                .frame(width: UIScreen.main.bounds.width * 0.3)
                .background(Color(red: 0.08, green: 0.1, blue: 0.15))
            }
            // 顶部右上角蓝牙状态与连接入口
            VStack {
                HStack {
                    Spacer()
                    BLEStatusIndicator { showDevicePicker = true }
                        .padding(.trailing, 12)
                        .padding(.top, 8)
                }
                Spacer()
            }
        }
        .alert("退出交易", isPresented: $showExitAlert) {
            Button("取消", role: .cancel) { }
            Button("确定退出", role: .destructive) {
                print("=== Exit trading confirmed ===")
                onExitTrading?()
            }
        } message: {
            Text("确定要退出当前交易回到选择界面吗？")
        }
        .sheet(isPresented: $showDevicePicker) {
            BLEDevicePickerSheet()
        }
    }
}

/// 图表容器视图 - 包装实时图表和控制按钮
struct ChartContainerView: View {
    let stock: StockData
    @State private var isPlaying = true  // 默认开启播放
    @State private var playSpeed: Double = 1.0
    @State private var isRandomMode: Bool = true // 添加模式状态

    // Current price states that you already have
    @State private var currentPrice: Double = 0
    @State private var openPrice: Double = 0 // Keeping this here for internal display logic
    @State private var changePercent: Double = 0 // Keeping this here for internal display logic

    // New: A callback to communicate price updates UP to the parent TradingView
    let onCurrentPriceUpdate: ((Double, Double, Double) -> Void)? // (currentPrice, openPrice, changePercent)

    // Add init if you want to set initial values for the @State variables based on stock data
    init(stock: StockData, onCurrentPriceUpdate: ((Double, Double, Double) -> Void)? = nil) {
        self.stock = stock
        self.onCurrentPriceUpdate = onCurrentPriceUpdate

        // Initialize @State values if the stock has data
        if let lastCandle = stock.candles.last {
            _currentPrice = State(initialValue: lastCandle.close)
            _openPrice = State(initialValue: lastCandle.open)
            _changePercent = State(initialValue: ((lastCandle.close - lastCandle.open) / lastCandle.open) * 100)
        }
    }


    var body: some View {
        VStack(spacing: 0) {
            // 顶部股票信息栏 + 控制按钮
            HStack {
                // 左侧：股票信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.symbol)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(stock.name)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // 中间：播放控制 + 模式切换
                VStack(spacing: 8) {
                    // 模式指示
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isRandomMode ? Color.orange : Color.blue)
                            .frame(width: 8, height: 8)
                        Text(isRandomMode ? "蜡烛内模拟" : "历史直显")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .onTapGesture {
                        isRandomMode.toggle()
                        print("=== Switched to \(isRandomMode ? "Intra-Candle Simulation" : "Direct Historical") mode ===")
                    }

                    // 播放/暂停按钮
                    Button(action: {
                        isPlaying.toggle()
                        print("=== Chart playback: \(isPlaying ? "Started" : "Paused") ===")
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text(isPlaying ? "暂停" : "开始")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isPlaying ? Color.orange : Color.green)
                        )
                    }
                    .buttonStyle(.plain)

                    // 速度显示
                    Text("速度: \(String(format: "%.1f", playSpeed))x")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()

                // 右侧：当前实时价格信息
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(String(format: "%.4f", currentPrice > 0 ? currentPrice : (stock.candles.last?.close ?? 0)))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Image(systemName: changePercent >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.caption2)
                            .foregroundColor(changePercent >= 0 ? .green : .red)

                        Text("\(changePercent >= 0 ? "+" : "")\(String(format: "%.2f", changePercent))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(changePercent >= 0 ? .green : .red)
                    }

                    Text("当前价格")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.3))
            .onAppear {
                // 初始化显示股票的最新价格，并同时通过回调通知父视图
                if let lastCandle = stock.candles.last {
                    self.currentPrice = lastCandle.close
                    self.openPrice = lastCandle.open
                    self.changePercent = ((lastCandle.close - lastCandle.open) / lastCandle.open) * 100
                    self.onCurrentPriceUpdate?(self.currentPrice, self.openPrice, self.changePercent)
                }
            }

            // 速度滑动条
            VStack(spacing: 4) {
                Slider(value: $playSpeed, in: 0.1...5.0, step: 0.1)
                    .accentColor(.orange)
                    .padding(.horizontal, 16)

                HStack {
                    Text("0.1x")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("5.0x")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))

            // 图表区域
            LightweightChartView(
                stock: stock,
                isPlaying: $isPlaying,
                playSpeed: $playSpeed,
                isRandomMode: $isRandomMode,
                onCurrentPriceUpdate: { price, open, percent in
                    // Update internal states for display within ChartContainerView
                    self.currentPrice = price
                    self.openPrice = open
                    self.changePercent = percent
                    // Also pass the update UP to the parent TradingView
                    self.onCurrentPriceUpdate?(price, open, percent)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// ... (LightweightChartView and ChartViewContainer remain the sa
/// 实时K线图表视图 - 使用UIViewRepresentable包装LightweightCharts
struct LightweightChartView: UIViewRepresentable {
    let stock: StockData
    @Binding var isPlaying: Bool
    @Binding var playSpeed: Double
    @Binding var isRandomMode: Bool
    let onCurrentPriceUpdate: ((Double, Double, Double) -> Void)?
    
    func makeUIView(context: Context) -> ChartViewContainer {
        let container = ChartViewContainer()
        container.setupChart(with: stock)
        container.setRandomMode(isRandomMode)
        container.onCurrentPriceUpdate = onCurrentPriceUpdate
        return container
    }
    
    func updateUIView(_ uiView: ChartViewContainer, context: Context) {
        uiView.updatePlayback(isPlaying: isPlaying, speed: playSpeed)
        uiView.setRandomMode(isRandomMode)
        uiView.onCurrentPriceUpdate = onCurrentPriceUpdate
    }
}

/// 图表容器类 - 管理LightweightCharts和实时数据
class ChartViewContainer: UIView {
    private var chart: LightweightCharts!
    private var candlestickSeries: CandlestickSeries!
    private var timer: Timer?
    
    // 历史数据相关
    private var currentIndex = 0
    private var allCandles: [CandlestickData] = []
    private var isPlaying = false
    private var playSpeed: Double = 1.0
    
    // 单根蜡烛内部随机模拟相关
    private var currentHistoricalCandle: CandlestickData?
    private var currentSimulatedBar: CandlestickData?
    private var ticksInCurrentBar = 0
    private var maxTicksPerBar = 20 // 每根蜡烛内部模拟20个tick
    private var isRandomMode = false
    
    // 当前蜡烛的OHLC约束
    private var currentOpen: Double = 0
    private var currentHigh: Double = 0
    private var currentLow: Double = 0
    private var currentClose: Double = 0
    
    // 当前价格回调
    var onCurrentPriceUpdate: ((Double, Double, Double) -> Void)? // (当前价格, 开盘价, 涨跌幅%)
    
    // 当前实时价格
    private var currentRealTimePrice: Double = 0 {
        didSet {
            // 计算当日涨跌幅百分比
            if currentOpen > 0 {
                let changePercent = ((currentRealTimePrice - currentOpen) / currentOpen) * 100
                onCurrentPriceUpdate?(currentRealTimePrice, currentOpen, changePercent)
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupChartView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupChartView()
    }

    private func setupChartView() {
        
        // 创建简化的图表配置 - 避免API兼容性问题
        let options = ChartOptions(
            layout: LayoutOptions(
                background: .solid(color: "#1a1a2e"),
                textColor: "#d1d5db"
            ),
            rightPriceScale: VisiblePriceScaleOptions(
                borderColor: "#4a5568"
            ),
            timeScale: TimeScaleOptions(
                borderColor: "#4a5568",
                timeVisible: true
            ),
            crosshair: CrosshairOptions(
                mode: .normal
            ),
            grid: GridOptions(
                verticalLines: GridLineOptions(
                    color: "#2d3748"
                ),
                horizontalLines: GridLineOptions(
                    color: "#2d3748"
                )
            )
        )
        
        // 创建图表实例
        chart = LightweightCharts(options: options)
        addSubview(chart)
        
        // 设置约束 - 正确的anchor处理
        chart.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chart.leadingAnchor.constraint(equalTo: leadingAnchor),
            chart.trailingAnchor.constraint(equalTo: trailingAnchor),
            chart.topAnchor.constraint(equalTo: topAnchor),
            chart.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        print("=== ChartViewContainer initialized with proper anchors ===")
    }
    
    func setupChart(with stock: StockData) {
        // 创建蜡烛图系列
        candlestickSeries = chart.addCandlestickSeries(options: CandlestickSeriesOptions(
            upColor: "#26a69a",
            downColor: "#ef5350",
            borderUpColor: "#26a69a", 
            borderDownColor: "#ef5350",
            wickUpColor: "#26a69a",
            wickDownColor: "#ef5350"
        ))
        
        // 获取随机起始点之前的所有历史数据
        let initialDisplayData = stock.getInitialDisplayData(upTo: 0) // 显示到随机起始点
        let remainingData = stock.getRemainingData(from: 0) // 待推进的数据
        
        // 转换初始显示数据
        let initialCandles = initialDisplayData.map { candle in
            CandlestickData(
                time: .string(formatDate(candle.timestamp)),
                open: candle.open,
                high: candle.high,
                low: candle.low,
                close: candle.close
            )
        }
        
        // 转换待推进数据
        allCandles = remainingData.map { candle in
            CandlestickData(
                time: .string(formatDate(candle.timestamp)),
                open: candle.open,
                high: candle.high,
                low: candle.low,
                close: candle.close
            )
        }
        
        // 显示随机起始点之前的所有数据
        if !initialCandles.isEmpty {
            candlestickSeries.setData(data: initialCandles)
            // 滚动到最右边（显示随机起始点）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.chart.timeScale().scrollToRealTime()
            }
            print("=== Chart setup: Displayed \(initialCandles.count) initial candles, \(allCandles.count) remaining ===")
        }
        
        // 从0开始推进
        currentIndex = 0
    }
    
    func updatePlayback(isPlaying: Bool, speed: Double) {
        let wasPlaying = self.isPlaying
        self.isPlaying = isPlaying
        self.playSpeed = speed
        
        if isPlaying && !wasPlaying {
            startRealTimeUpdates()
        } else if !isPlaying && wasPlaying {
            stopRealTimeUpdates()
        } else if isPlaying && wasPlaying {
            // 只更新速度，重启timer
            startRealTimeUpdates()
        }
    }
    
    // 新增：切换模式的公共方法
    func setRandomMode(_ enabled: Bool) {
        isRandomMode = enabled
        if enabled {
            print("=== Switched to Random Price Simulation Mode ===")
        } else {
            print("=== Switched to Historical Data Playback Mode ===")
        }
    }
    
    private func startRealTimeUpdates() {
        stopRealTimeUpdates() // 先停止现有的timer
        
        let interval = max(0.1, 0.2 / playSpeed) // 基于速度调整间隔
        
        if isRandomMode {
            // 随机模式：在历史数据基础上进行蜡烛内部模拟
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.tickWithinHistoricalCandle()
            }
            print("=== Started intra-candle random simulation with interval: \(interval)s ===")
        } else {
            // 历史数据模式：直接显示历史蜡烛
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.showNextHistoricalCandle()
            }
            print("=== Started historical candle display with interval: \(interval)s ===")
        }
        
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func stopRealTimeUpdates() {
        timer?.invalidate()
        timer = nil
        print("=== Stopped real-time updates ===")
    }
    
    // MARK: - 蜡烛内部随机模拟方法
    
    private func tickWithinHistoricalCandle() {
        // 检查是否需要加载下一根历史蜡烛
        if currentHistoricalCandle == nil {
            loadNextHistoricalCandle()
        }
        
        guard let historicalCandle = currentHistoricalCandle else {
            print("=== No more historical data available ===")
            stopRealTimeUpdates()
            return
        }
        
        // 在当前蜡烛内部生成随机tick
        let randomPrice = generateRandomPriceWithinCandle(historicalCandle)
        updateCurrentSimulatedBar(with: randomPrice, from: historicalCandle)
        
        ticksInCurrentBar += 1
        
        // 当达到最大tick数时，确保最终价格为历史收盘价
        if ticksInCurrentBar >= maxTicksPerBar {
            finalizeCurrentCandle(with: historicalCandle)
            moveToNextCandle()
        }
    }
    
    private func loadNextHistoricalCandle() {
        guard currentIndex < allCandles.count else {
            print("=== Reached end of historical data ===")
            return
        }
        
        currentHistoricalCandle = allCandles[currentIndex]
        currentIndex += 1
        
        // 设置当前蜡烛的OHLC约束
        if let candle = currentHistoricalCandle {
            currentOpen = candle.open ?? 0
            currentHigh = candle.high ?? 0
            currentLow = candle.low ?? 0
            currentClose = candle.close ?? 0
            
            // 初始化当前实时价格为开盘价
            currentRealTimePrice = currentOpen
            
            // 重置tick计数和模拟蜡烛
            ticksInCurrentBar = 0
            currentSimulatedBar = CandlestickData(
                time: candle.time,
                open: currentOpen,
                high: currentOpen,
                low: currentOpen,
                close: currentOpen
            )
            
            print("=== Loading historical candle \(currentIndex)/\(allCandles.count): O:\(currentOpen) H:\(currentHigh) L:\(currentLow) C:\(currentClose) ===")
        }
    }
    
    private func generateRandomPriceWithinCandle(_ candle: CandlestickData) -> Double {
        let open = candle.open ?? 0
        let high = candle.high ?? 0
        let low = candle.low ?? 0
        let close = candle.close ?? 0
        
        // 根据tick进度调整价格倾向
        let progress = Double(ticksInCurrentBar) / Double(maxTicksPerBar)
        
        // 早期tick：在开盘价附近波动
        // 中期tick：可以达到高低点
        // 后期tick：逐渐向收盘价靠拢
        let targetPrice: Double
        if progress < 0.3 {
            // 早期：开盘价附近
            targetPrice = open + (high - low) * 0.1 * (Double.random(in: -1...1))
        } else if progress < 0.7 {
            // 中期：可能触及高低点
            targetPrice = Double.random(in: low...high)
        } else {
            // 后期：向收盘价靠拢
            let weight = (progress - 0.7) / 0.3 // 0到1之间
            let randomInRange = Double.random(in: low...high)
            targetPrice = randomInRange * (1 - weight) + close * weight
        }
        
        // 确保价格在历史范围内
        return max(low, min(high, targetPrice))
    }
    
    private func updateCurrentSimulatedBar(with price: Double, from historicalCandle: CandlestickData) {
        guard var simulatedBar = currentSimulatedBar else { return }
        
        // 更新模拟蜡烛的OHLC
        simulatedBar.close = price
        simulatedBar.high = max(simulatedBar.high ?? price, price)
        simulatedBar.low = min(simulatedBar.low ?? price, price)
        
        // 确保不超出历史数据的边界
        simulatedBar.high = min(simulatedBar.high ?? 0, currentHigh)
        simulatedBar.low = max(simulatedBar.low ?? Double.greatestFiniteMagnitude, currentLow)
        
        currentSimulatedBar = simulatedBar
        candlestickSeries.update(bar: simulatedBar)
        
        // 更新当前实时价格
        currentRealTimePrice = price
    }
    
    private func finalizeCurrentCandle(with historicalCandle: CandlestickData) {
        // 确保最终蜡烛与历史数据完全一致
        let finalBar = CandlestickData(
            time: historicalCandle.time,
            open: currentOpen,
            high: currentHigh,
            low: currentLow,
            close: currentClose // 必须是历史收盘价
        )
        
        candlestickSeries.update(bar: finalBar)
        print("=== Finalized candle with historical close: \(currentClose) ===")
    }
    
    private func moveToNextCandle() {
        currentHistoricalCandle = nil
        currentSimulatedBar = nil
        ticksInCurrentBar = 0
        
        // 每完成5根蜡烛打印进度
        if currentIndex % 5 == 0 {
            print("=== Simulation progress: \(currentIndex)/\(allCandles.count) candles completed ===")
        }
    }
    
    
    // MARK: - 历史数据直接显示方法
    
    private func showNextHistoricalCandle() {
        guard currentIndex < allCandles.count else {
            print("=== Reached end of historical data ===")
            stopRealTimeUpdates()
            return
        }
        
        // 直接显示下一根历史蜡烛
        let nextCandle = allCandles[currentIndex]
        candlestickSeries.update(bar: nextCandle)
        currentIndex += 1
        
        // 更新当前价格为历史收盘价
        if let close = nextCandle.close, let open = nextCandle.open {
            currentOpen = open
            currentRealTimePrice = close
        }
        
        // 每添加10根蜡烛打印一次日志
        if currentIndex % 10 == 0 || currentIndex == allCandles.count {
            print("=== Historical display progress: \(currentIndex)/\(allCandles.count) candles ===")
        }
    }
    
    
    // MARK: - 时间格式化方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    deinit {
        stopRealTimeUpdates()
        print("=== ChartViewContainer deallocated ===")
    }
}

#Preview {
    TradingView(
        viewModel: GameViewModel(),
        selectedStock: StockData(
            symbol: "BTCUSDT",
            name: "比特币",
            candles: []
        )
    )
}
