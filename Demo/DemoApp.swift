//
//  DemoApp.swift
//  Demo
//
//  Created by Pushy on 3/26/24.
//  Copyright © 2024 Pushy. All rights reserved.
//

import SwiftUI
import UserNotifications

@main
struct DemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
