//
//  AppDelegate.swift
//  Demo
//
//  Created by Pushy on 3/26/24.
//  Copyright © 2024 Pushy. All rights reserved.
//

import Foundation
import AppKit
import SwiftUI
import PushySDK
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Pushy SDK
        let pushy = Pushy(NSApplication.shared)
        
        // Replace with your Pushy App ID
        pushy.setAppId("550ee57c5b5d72117f51e801")
        
        // Register the device for push notifications
        pushy.register({ (error, deviceToken) in
            // Handle registration errors
            if error != nil {
                return print ("Registration failed: \(error!.localizedDescription)")
            }
            
            // Print device token to console
            print("Pushy device token: \(deviceToken)")
            
            // Persist the device token locally and send it to your backend later
            UserDefaults.standard.set(deviceToken, forKey: "pushyToken")
        })
        
        // Handle incoming notifications
        pushy.setNotificationHandler({ (data) in
            // Print notification payload
            print("Received notification: \(data)")
            
            // Create a content object
            let content = UNMutableNotificationContent()
            
            // Set title if passed in
            if let title = data["title"] as? String {
                content.title = title
            }
            
            // Set message if passed in
            if let message = data["message"] as? String {
                content.body = message
            }
            
            // Set badge if passed in
            if let badge = data["badge"] as? Int {
                content.badge = NSNumber(value: badge)
            }
            
            // Set default sound
            content.sound = .default
            
            // Pass payload in user info (to pass it onto notification click handler)
            content.userInfo = data
                        
            // Display the notification
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)) { error in
                // Log errors to console
                if let error = error {
                    print("Error posting local notification: \(error)")
                }
            }
            
            // Show an alert dialog
            let alert: NSAlert = NSAlert()
            alert.messageText = "Incoming Notification"
            alert.informativeText = data["message"] as! String
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        })
        
        // Handle notification tap event
        pushy.setNotificationClickListener({ (data) in
            // Show an alert dialog
            let alert: NSAlert = NSAlert()
            alert.messageText = "Notification Click"
            alert.informativeText = data["message"] as! String
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            
            // Navigate the user to another page or
            // execute other logic on notification click
        })
    }
}
