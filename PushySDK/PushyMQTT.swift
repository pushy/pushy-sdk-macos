//
//  PushyMQTT.swift
//  PushySDK
//
//  Created by Pushy on 2/9/22.
//  Copyright © 2022 Pushy. All rights reserved.
//

import CocoaMQTT

public class PushyMQTT: CocoaMQTTDelegate {
    // MQTT connection handle
    private var mqtt: CocoaMQTT?
    
    public func connect() {
        // Ensure device is registered and load token & auth
        guard let token = PushySettings.getString(PushySettings.pushyToken), let auth = PushySettings.getString(PushySettings.pushyTokenAuth) else {
            print("MQTT connection failed: The device is not registered for notifications.")
            return
        }
    
        // Already connected or connecting?
        if (mqtt?.connState == CocoaMQTTConnState.connected || mqtt?.connState == CocoaMQTTConnState.connecting) {
            // Do nothing
            return
        }
                
        // Log connecting
        print("PushyMQTT: Connecting...")
        
        // Substitue {ts} with current Unix timestamp for DNS load balancing anti-caching
        let hostName = PushyConfig.mqttHostname.replacingOccurrences(of: "{ts}", with: String(Int(Date().timeIntervalSince1970)))
        
        // Create new CocoaMQTT long-lived instance
        mqtt = CocoaMQTT(clientID: token, host: hostName, port: UInt16(PushyConfig.mqttPort))
        
        // Set device token & auth key as username and password
        mqtt?.username = token
        mqtt?.password = auth
        
        // TLS support
        mqtt?.enableSSL = true
        
        // Set keep alive (in seconds)
        mqtt?.keepAlive = UInt16(PushySettings.getInteger(PushySettings.pushyKeepAlive, PushyConfig.mqttDefaultKeepAliveInterval))
        
        // Hook into MQTT lifecycle methods
        mqtt?.delegate = self
        
        // Auto reconnect on disconnect
        mqtt?.autoReconnect = true
        
        // Try establishing connection
        _ = mqtt?.connect()
    }
    
    public func disconnect() {
        // Log network extension stop() called
        print("PushyMQTT: Disconnecting...")
        
        // If connected, disconnect forcibly
        if (mqtt?.connState == CocoaMQTTConnState.connected) {
            mqtt?.disconnect()
            mqtt = nil
        }
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        // Log successful connection
        print("PushyMQTT: Connected successfully")
    }
    
    public func mqttDidPing(_ mqtt: CocoaMQTT) {
        // Log keep alive packet sent
        print("PushyMQTT: Sending keep alive")
    }
    
    public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        // Log connection lost
        print("PushyMQTT: Connection lost")
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        // Log incoming notification received
        print("PushyMQTT: Received notification")
        
        // Convert payload data to JSON
        if let data = message.string?.data(using: .utf8) {
            do {
                // Decode UTF-8 string into JSON
                let payload = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                
                // Invoke notification handler if app running
                Pushy.shared?.invokeNotificationHandler(payload)
            }
            catch {
                // Print JSON parse error to console
                print("PushyMQTT: Error decoding payload into JSON: " + error.localizedDescription)
            }
        }
    }
    
    // Unused callbacks
    public func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}
    public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {}
    public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}
    public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {}
    public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}
}
