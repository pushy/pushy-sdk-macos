//
//  PushyConfig.swift
//  Pushy
//
//  Created by Pushy on 10/8/16.
//  Copyright © 2016 Pushy. All rights reserved.
//

import Foundation

public class PushyConfig {
    // API endpoint
    static var apiBaseUrl = "https://api.pushy.me"
    
    // MQTT hostname
    static var mqttHostname = "mqtt-{ts}.pushy.io"
    
    // MQTT port number
    static var mqttPort = 443
    
    // Default MQTT keep alive interval in seconds (5 minutes)
    static var mqttDefaultKeepAliveInterval = 60 * 5
}
