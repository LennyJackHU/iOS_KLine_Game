//
//  CoinInsertionView.swift
//  KLineSwift
//
//  投币界面 - 模拟ESP32投币检测功能
//

import SwiftUI
import CoreBluetooth

/// 投币界面视图
struct CoinInsertionView: View {
    let requiredCoins: Int
    let onCoinsInserted: (Int) -> Void
    let onCancel: () -> Void
    
    @State private var insertedCoins: Int = 0
    @State private var isCompleted: Bool = false
    @State private var animationScale: Double = 1.0
    @State private var coinRotation: Double = 0
    @State private var showCompletionDelay: Bool = false
    @ObservedObject private var ble = BLEManager.shared
    @State private var taskStarted: Bool = false
    
    var body: some View {
        ZStack {
            // 深色半透明背景
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    // 防止误触关闭
                }
            
            // 主内容区域
            VStack(spacing: 0) {
                if !isCompleted {
                    coinInsertionContent
                } else {
                    coinCompletionContent
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.1, green: 0.12, blue: 0.16))
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            )
            .scaleEffect(animationScale)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animationScale)
        }
        .onAppear {
            startAnimations()
            if !taskStarted {
                taskStarted = true
                // 新会话前清零显示
                BLEManager.shared.resetDisplayedCoinCount()
                Task { @MainActor in
                    let got = await CoinBox.waitUntil(required: requiredCoins)
                    insertedCoins = got
                    // 触发完成动画（与模拟路径保持一致节奏）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isCompleted = true
                            animationScale = 1.2
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            animationScale = 1.0
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 投币等待内容
    
    private var coinInsertionContent: some View {
        VStack(spacing: 24) {
            // 标题
            Text("投币等待")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            // 大硬币图标区域
            VStack(spacing: 16) {
                // 硬币emoji
                Text("🪙")
                    .font(.system(size: 120))
                    .rotationEffect(.degrees(coinRotation))
                    .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: coinRotation)
                    .shadow(color: .yellow.opacity(0.6), radius: 10, x: 0, y: 0)
                
                // 投币提示
                Text("请投入 \(requiredCoins) 枚游戏币")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // 进度显示（优先显示硬件计数）
                Text("已投入: \(displayInserted())/\(requiredCoins)")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.2))
                    )
            }
            
            Spacer()
            
            // 货币选择按钮（连接硬件后隐藏模拟按钮）
            if !ble.isConnected {
                VStack(spacing: 16) {
                    Text("货币选择:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack(spacing: 16) {
                        coinButton(amount: 1, color: .cyan)
                        coinButton(amount: 2, color: .yellow)
                        coinButton(amount: 5, color: .green)
                    }
                }
            }
            
            Spacer()
            
            // 取消交易按钮
            Button(action: {
                cancelTransaction()
            }) {
                Text("取消交易")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.8))
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(width: 300)
    }
    
    // MARK: - 投币完成内容
    
    private var coinCompletionContent: some View {
        VStack(spacing: 24) {
            // 标题
            Text("投币等待")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            // 成功图标
            VStack(spacing: 16) {
                // 绿色勾号
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 120, height: 120)
                        .shadow(color: .green.opacity(0.6), radius: 15, x: 0, y: 0)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(animationScale)
                
                // 完成提示
                Text("投币完成！")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // 收到的游戏币数量
                Text("已收到 \(requiredCoins) 枚游戏币")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            // 自动继续提示
            Text("3秒后自动继续...")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .opacity(showCompletionDelay ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: showCompletionDelay)
            
            Spacer()
        }
        .frame(width: 300)
        .onAppear {
            // 显示延迟提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showCompletionDelay = true
            }
            
            // 3秒后自动关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                completeTransaction()
            }
        }
    }
    
    // MARK: - 货币选择按钮
    
    private func coinButton(amount: Int, color: Color) -> some View {
        Button(action: {
            insertCoins(amount)
        }) {
            Text("\(amount)个")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 80, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.8))
                )
        }
        .buttonStyle(.plain)
        .disabled(insertedCoins >= requiredCoins)
    }
    
    // MARK: - 动作方法
    
    private func startAnimations() {
        // 入场动画
        animationScale = 0.8
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            animationScale = 1.0
        }
        
        // 硬币旋转动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            coinRotation = 360
        }
    }
    
    private func insertCoins(_ amount: Int) {
        let newTotal = min(insertedCoins + amount, requiredCoins)
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            insertedCoins = newTotal
            animationScale = 1.1
        }
        
        // 恢复缩放
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            animationScale = 1.0
        }
        
        // 播放投币音效（模拟）
        print("=== 投入 \(amount) 枚游戏币，总计: \(insertedCoins)/\(requiredCoins) ===")
        
        // 检查是否完成
        if insertedCoins >= requiredCoins {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isCompleted = true
                    animationScale = 1.2
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animationScale = 1.0
                }
            }
        }
    }
    
    private func cancelTransaction() {
        print("=== 取消投币交易 ===")
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            animationScale = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onCancel()
        }
    }
    
    private func completeTransaction() {
        print("=== 投币完成，开始交易 ===")
        // 优先选择硬件计数
        let total = max(insertedCoins, ble.currentCoinTotal)
        onCoinsInserted(min(total, requiredCoins))
    }

    private func displayInserted() -> Int {
        let hw = ble.currentCoinTotal
        if hw > 0 { return min(hw, requiredCoins) }
        return insertedCoins
    }
}

// MARK: - 预览

#Preview {
    CoinInsertionView(
        requiredCoins: 10,
        onCoinsInserted: { coins in
            print("收到 \(coins) 枚游戏币")
        },
        onCancel: {
            print("取消投币")
        }
    )
}