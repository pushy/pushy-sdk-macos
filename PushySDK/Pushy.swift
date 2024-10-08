//
//  Pushy.swift
//  Pushy
//
//  Created by Pushy on 10/7/16.
//  Copyright © 2016 Pushy. All rights reserved.
//

import AppKit
import CocoaMQTT

#if canImport(UserNotifications)
    import UserNotifications
#else
    public protocol UNUserNotificationCenterDelegate {}
#endif

public class Pushy : NSObject, UNUserNotificationCenterDelegate {
    public static var shared: Pushy?
    
    private var mqtt: PushyMQTT?
    private var application: NSApplication
    private var registrationHandler: ((Error?, String) -> Void)?
    private var notificationHandler: (([AnyHashable : Any]) -> Void)?
    private var notificationClickListener: (([AnyHashable : Any]) -> Void)?
    private var notificationOptions: Any?
    
    @objc public init(_ application: NSApplication) {
        // Store application and app delegate for later
        self.application = application
        
        // Initialize Pushy instance before accessing the self object
        super.init()
        
        // Store Pushy instance for later, but don't overwrite an existing instance if already initialized
        if Pushy.shared == nil {
            Pushy.shared = self
        }
        
        // Listen for notifications
        self.listen()
    }
    
    @objc public func listen() {
        // Check if device is already registered
        if isRegistered() {
            // Instantiate MQTT client
            if mqtt == nil {
                mqtt = PushyMQTT()
            }
            
            // Connect MQTT client
            mqtt!.connect()
        }
    }
    
    // Device connectivity check
    @objc public func isConnected() -> Bool {
        // Check if device is already registered
        if !isRegistered() {
            return false
        }
        
        // MQTT not initialized?
        if mqtt == nil {
            return false
        }
        
        // Query connection state
        return mqtt!.getConnectionState() == CocoaMQTTConnState.connected
    }
    
    // Device connectivity check
    @objc public func isConnecting() -> Bool {
        // Check if device is already registered
        if !isRegistered() {
            return false
        }
        
        // MQTT not initialized?
        if mqtt == nil {
            return false
        }
        
        // Query connection state
        return mqtt!.getConnectionState() == CocoaMQTTConnState.connecting
    }
    
    // Define a notification handler to invoke when device receives a notification
    @objc public func setNotificationHandler(_ notificationHandler: @escaping ([AnyHashable : Any]) -> Void) {
        // Save the handler for later
        self.notificationHandler = notificationHandler
        
        // Ensure we have access to the UserNotifications framework
        #if canImport(UserNotifications)
            // Set delegate to hook into userNotificationCenter callbacks
            UNUserNotificationCenter.current().delegate = self
        #endif
    }
    
    // Define a notification click handler to invoke when user taps a notification
    @objc public func setNotificationClickListener(_ notificationClickListener: @escaping ([AnyHashable : Any]) -> Void) {
        // Save the listener for later
        self.notificationClickListener = notificationClickListener
    }
    
    // Ensure we have access to the UserNotifications framework
    #if canImport(UserNotifications)
        // Notification click, invoke notification click listener
        public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
            // Call the notification click listener, if defined
            Pushy.shared?.notificationClickListener?(response.notification.request.content.userInfo)
            
            // Finished processing notification
            completionHandler()
        }
    #endif
    
    // Make it possible to pass in custom notification options ([.badge, .sound, .alert, ...])
    @objc public func setCustomNotificationOptions(_ options:Any) {
        // Save the options for later
        self.notificationOptions = options
    }
    
    // Register for push notifications
    @objc public func register(_ registrationHandler: @escaping (Error?, String) -> Void) {
        // Ensure we have access to the UserNotifications framework
        #if canImport(UserNotifications)
            // Default options
            var options: UNAuthorizationOptions = [.badge, .alert, .sound]
            
            // Custom options passed in?
            if let customOptions = notificationOptions {
                options = customOptions as! UNAuthorizationOptions
            }
        
            // Request macOS Notification Center permission from user
            UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, error) in
                // Ignore permission grant/rejection for now
                // as the notification handler will still be invoked if permission denied
            }
        #endif
        
        // Save the registration handler for later
        self.registrationHandler = registrationHandler
        
        // Register directly with Pushy API
        Pushy.shared?.registerPushyDevice()
    }
    
    // Unregister from push notifications
    @objc public func unregister() {
        // Unregister device
        PushySettings.setString(PushySettings.pushyToken, nil)
        PushySettings.setString(PushySettings.pushyTokenAuth, nil)
        
        // Disconnect MQTT connection
        mqtt?.disconnect()
    }
    
    // Assigns a Pushy device token to the device
    private func registerPushyDevice() {
        // Attempt to fetch persisted Pushy token
        let token = PushySettings.getString(PushySettings.pushyToken)
        
        // First time?
        if token == nil {
            // Create a new Pushy device
            return createNewDevice()
        }
        
        // Validate existing device credentials
        validateCredentials({ (error, credentialsValid) in
            // Handle validation errors
            if error != nil {
                self.registrationHandler?(error, "")
                return
            }
            
            // Are credentials invalid?
            if !credentialsValid {
                // Create a new device using the token
                return self.createNewDevice()
            }
            
            // Registration success
            self.registrationHandler?(nil, token!)
            
            // Listen for notifications
            self.listen()
        })
    }
    
    // Register a new Pushy device
    private func createNewDevice() {
        // Fetch app bundle ID
        let bundleId = Bundle.main.bundleIdentifier
        
        // Bundle ID fetch failed?
        guard let appBundleId = bundleId else {
            registrationHandler?(PushyRegistrationException.Error("Please configure a Bundle ID for your app to use Pushy.", "MISSING_BUNDLE_ID"), "")
            return
        }
        
        // Fetch custom Pushy App ID (may be null)
        let appId = PushySettings.getString(PushySettings.pushyAppId)
                
        // Prepare /register API post data
        var params: [String:Any] = ["platform": "macos", "app": appBundleId ]
        
        // Authenticate using Bundle ID by default
        if appId == nil {
            params["app"] = appBundleId
        }
        else {
            // Authenticate using provided Pushy App ID
            params["appId"] = appId!
        }
        
        // Execute post request
        PushyHTTP.postAsync(self.getApiEndpoint() + "/register", params: params) { (err: Error?, response: [String:AnyObject]?) -> () in
            // JSON parse error?
            if err != nil {
                self.registrationHandler?(err, "")
                return
            }
            
            // Unwrap response json
            guard let json = response else {
                self.registrationHandler?(PushyRegistrationException.Error("An invalid response was encountered.", "INVALID_JSON_RESPONSE"), "")
                return
            }
            
            // If we are here, registration succeeded
            let deviceToken = json["token"] as! String
            let deviceAuth = json["auth"] as! String
            
            // Store device token and auth in UserDefaults
            PushySettings.setString(PushySettings.pushyToken, deviceToken)
            PushySettings.setString(PushySettings.pushyTokenAuth, deviceAuth)
            
            // All done
            self.registrationHandler?(nil, deviceToken)
            
            // Listen for notifications
            self.listen()
        }
    }
    
    // Validate device token and auth key
    private func validateCredentials(_ resultHandler: @escaping (Error?, Bool) -> Void) {
        // Load device token & auth
        guard let pushyToken = PushySettings.getString(PushySettings.pushyToken), let pushyTokenAuth = PushySettings.getString(PushySettings.pushyTokenAuth) else {
            return resultHandler(PushyRegistrationException.Error("Failed to load the device credentials.", "DEVICE_CREDENTIALS_ERROR"), false)
        }
        
        // Prepare request params
        let params: [String:Any] = ["token": pushyToken, "auth": pushyTokenAuth]
        
        // Execute post request
        PushyHTTP.postAsync(self.getApiEndpoint() + "/devices/auth", params: params) { (err: Error?, response: [String:AnyObject]?) -> () in
            // JSON parse error?
            if err != nil {
                // Did we get json["error"] response exception?
                if err is PushyResponseException {
                    // Auth is invalid
                    return resultHandler(nil, false)
                }
                
                // Throw network error and stop execution
                return resultHandler(err, false)
            }
            
            // Unwrap json
            guard let json = response else {
                return resultHandler(PushyRegistrationException.Error("An invalid response was encountered when validating device credentials.", "INVALID_JSON_RESPONSE"), false)
            }
            
            // Get success value
            let success = json["success"] as! Bool
            
            // Verify credentials validity
            if !success {
                return resultHandler(nil, false)
            }
            
            // Credentials are valid!
            resultHandler(nil, true)
        }
    }
    
    // Subscribe to single topic
    @objc public func subscribe(topic: String, handler: @escaping (Error?) -> Void) {
        // Call multi-topic subscribe function
        subscribe(topics: [topic], handler: handler)
    }
    
    // Subscribe to multiple topics
    @objc public func subscribe(topics: [String], handler: @escaping (Error?) -> Void) {
        // Load device token & auth
        guard let pushyToken = PushySettings.getString(PushySettings.pushyToken), let pushyTokenAuth = PushySettings.getString(PushySettings.pushyTokenAuth) else {
            return handler(PushyRegistrationException.Error("Failed to load the device credentials.", "DEVICE_CREDENTIALS_ERROR"))
        }
        
        // Prepare request params
        let params: [String:Any] = ["token": pushyToken, "auth": pushyTokenAuth, "topics": topics]
        
        // Execute post request
        PushyHTTP.postAsync(self.getApiEndpoint() + "/devices/subscribe", params: params) { (err: Error?, response: [String:AnyObject]?) -> () in
            // JSON parse error?
            if err != nil {
                // Throw network error and stop execution
                return handler(err)
            }
            
            // Unwrap json
            guard let json = response else {
                return handler(PushyPubSubException.Error("An invalid response was encountered when subscribing the device to topic(s)."))
            }
            
            // Get success value
            let success = json["success"] as! Bool
            
            // Verify subscribe success
            if !success {
                return handler(PushyPubSubException.Error("An invalid response was encountered."))
            }
            
            // Subscribe success
            handler(nil)
        }
    }
    
    
    // Unsubscribe from single topic
    @objc public func unsubscribe(topic: String, handler: @escaping (Error?) -> Void) {
        // Call multi-topic unsubscribe function
        unsubscribe(topics: [topic], handler: handler)
    }
    
    // Unsubscribe from multiple topics
    @objc public func unsubscribe(topics: [String], handler: @escaping (Error?) -> Void) {
        // Load device token & auth
        guard let pushyToken = PushySettings.getString(PushySettings.pushyToken), let pushyTokenAuth = PushySettings.getString(PushySettings.pushyTokenAuth) else {
            return handler(PushyRegistrationException.Error("Failed to load the device credentials.", "DEVICE_CREDENTIALS_ERROR"))
        }
        
        // Prepare request params
        let params: [String:Any] = ["token": pushyToken, "auth": pushyTokenAuth, "topics": topics]
        
        // Execute post request
        PushyHTTP.postAsync(self.getApiEndpoint() + "/devices/unsubscribe", params: params) { (err: Error?, response: [String:AnyObject]?) -> () in
            // JSON parse error?
            if err != nil {
                // Throw network error and stop execution
                return handler(err)
            }
            
            // Unwrap json
            guard let json = response else {
                return handler(PushyPubSubException.Error("An invalid response was encountered when unsubscribing the device to topic(s)."))
            }
            
            // Get success value
            let success = json["success"] as! Bool
            
            // Verify unsubscribe success
            if !success {
                return handler(PushyPubSubException.Error("An invalid response was encountered."))
            }
            
            // Unsubscribe success
            handler(nil)
        }
    }
    
    public func invokeNotificationHandler(_ userInfo: [AnyHashable : Any]) {
        // Call the incoming notification handler
        Pushy.shared?.notificationHandler?(userInfo)
    }
    
    // Support for Pushy Enterprise
    @objc public func setEnterpriseConfig(apiEndpoint: String?) {
        // If nil, clear persisted Pushy Enterprise API endpoint
        if (apiEndpoint == nil) {
            return PushySettings.setString(PushySettings.pushyEnterpriseApi, nil)
        }
        
        // Mutable variable
        var endpoint = apiEndpoint!
        
        // Strip trailing slash
        if endpoint.hasSuffix("/") {
            endpoint = String(endpoint.prefix(endpoint.count - 1))
        }
        
        // Fetch previous enterprise endpoint
        let previousEndpoint = PushySettings.getString(PushySettings.pushyEnterpriseApi)
        
        // Check if this is a new API endpoint URL
        if endpoint != previousEndpoint {
            // Unregister device
            self.unregister()
        }
        
        // Persist enterprise API endpoint
        PushySettings.setString(PushySettings.pushyEnterpriseApi, endpoint)
    }
    
    // Set custom MQTT keep alive interval
    public func setKeepAliveInterval(seconds: Int?) {
        // If nil, clear persisted interval (use default)
        if (seconds == nil) {
            return PushySettings.setInteger(PushySettings.pushyKeepAlive, nil)
        }
        
        // Persist new keep alive interval
        PushySettings.setInteger(PushySettings.pushyKeepAlive, seconds)
    }
    
    // Support for Pushy App ID authentication instead of Bundle ID-based auth
    @objc public func setAppId(_ appId: String?) {
        // Fetch previous App ID
        let previousAppId = PushySettings.getString(PushySettings.pushyAppId)
        
        // Check if this is a new Pushy App ID
        if appId != previousAppId {
            // Unregister device
            self.unregister()
        }
        
        // Update stored value
        if (appId != nil) {
            PushySettings.setString(PushySettings.pushyAppId, appId!)
        }
        else {
            PushySettings.setString(PushySettings.pushyAppId, nil)
        }
    }
    
    // Device registration check
    @objc public func isRegistered() -> Bool {
        // Check if Pushy device token is assigned to current app instance
        if (PushySettings.getString(PushySettings.pushyToken, userDefaultsOnly: true) == nil) {
            return false
        }
        
        // Fallback to true
        return true
    }
    
    // API endpoint getter function
    @objc public func getApiEndpoint() -> String {
        // Check for a configured enterprise API endpoint
        let enterpriseApiEndpoint = PushySettings.getString(PushySettings.pushyEnterpriseApi)
        
        // Return enterprise endpoint if not nil
        if enterpriseApiEndpoint != nil {
            return enterpriseApiEndpoint!
        }
        
        // Default to public Pushy API endpoint if both proxy and enterprise endpoints are nil
        return PushyConfig.apiBaseUrl
    }
}

