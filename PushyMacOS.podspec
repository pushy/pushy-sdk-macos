Pod::Spec.new do |s|
    s.name                  = 'PushyMacOS'
    s.version               = '1.0.0'
    s.summary               = 'The official Pushy SDK for native macOS apps.'
    s.description           = 'Pushy is the most reliable push notification gateway, perfect for real-time, mission-critical applications.'
    s.homepage              = 'https://pushy.me/'

    s.author                = { 'Pushy' => 'contact@pushy.me' }
    s.license               = { :type => 'Apache-2.0', :file => 'LICENSE' }

    s.platform              = :osx
    s.source                = { :git => 'https://github.com/pushy/pushy-sdk-macos.git', :tag => s.version }
    s.source_files          = 'PushySDK/*.swift'
    s.swift_version         = '5.0'
    s.osx.deployment_target = '10.15'

    # CocoaMQTT
    s.dependency 'CocoaMQTT', '2.1.0'

    # Apple Privacy Manifest
    s.resource_bundle = {
        "Pushy_Privacy" => "Resources/PrivacyInfo.xcprivacy"
    }
end
