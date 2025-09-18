//
//  ContentView.swift
//  KLineSwift
//
//  Created by YiJia Hu on 2025/9/12.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var gameViewModel = GameViewModel()
    
    var body: some View {
        // 直接显示股票选择界面用于测试按钮点击
        StockSelectionView(viewModel: gameViewModel)
    }
}

#Preview {
    ContentView()
}
