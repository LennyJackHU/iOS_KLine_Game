//
//  KLineSwiftApp.swift
//  KLineSwift
//
//  Created by YiJia Hu on 2025/9/12.
//

import SwiftUI

@main
struct KLineSwiftApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            // Restored original app flow for testing improved StockCardView buttons
            ContentView()
        }
    }
}

// MARK: - AppDelegate for orientation control
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.landscape
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
        return true
    }
}
