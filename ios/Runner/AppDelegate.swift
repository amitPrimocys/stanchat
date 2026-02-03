import AVFoundation
import AudioToolbox
import CallKit
import ContactsUI
import FirebaseCore
import Flutter
import GoogleMaps
import MediaPlayer
import Security
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Clear keychain on first run
        if UserDefaults.standard.object(forKey: "FirstRun") == nil {
            print("🆕 First run detected - clearing ALL app data")
            debugListKeychainItems()
            clearFlutterSecureStorageKeychain()
            clearAllUserDefaults()
            UserDefaults.standard.setValue("1strun", forKey: "FirstRun")
            UserDefaults.standard.synchronize()
            print("✅ First run setup completed")
        }

        FirebaseApp.configure()
        GMSServices.provideAPIKey("AIzaSyDyxOlmDjz1MqOkSnvVjaJmZJnNNVZcVh4")

        GeneratedPluginRegistrant.register(with: self)

        // ==================== NOTIFICATION HANDLING ====================
        // ✅ CRITICAL FIX: Register for remote notifications to handle cold start
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        // Check if app was launched from notification
        if let notification = launchOptions?[.remoteNotification] as? [String: AnyObject] {
            print("🔔 App launched from notification (cold start)")
            print("📦 Notification payload: \(notification)")
            // The notification will be handled by OneSignal once Flutter is initialized
        }

        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController

        // ==================== CONTACTS CHANNEL ====================
        let contactChannel = FlutterMethodChannel(
            name: "com.primocys.chat/contacts",
            binaryMessenger: controller.binaryMessenger)

        contactChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "addContact" {
                self.addContact(call: call, result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        })

        // ==================== NOTIFICATION CHANNEL ====================
        let notificationChannel = FlutterMethodChannel(
            name: "primocys.call.notification",
            binaryMessenger: controller.binaryMessenger)

        notificationChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "getRingerMode":
                result(self.getRingerMode())
            case "playSystemRingtone":
                self.playSystemRingtone()
                result(nil)
            case "stopSystemRingtone":
                self.stopSystemRingtone()
                result(nil)
            case "startVibration":
                self.startVibration()
                result(nil)
            case "stopVibration":
                self.stopVibration()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        })

        // ==================== DEVICE PROFILE CHANNEL ====================
        let deviceProfileChannel = FlutterMethodChannel(
            name: "primocys.device.profile",
            binaryMessenger: controller.binaryMessenger)

        deviceProfileChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "getRingerMode" {
                result(self.getRingerMode())
            } else {
                result(FlutterMethodNotImplemented)
            }
        })

        // ==================== AUDIO CHANNEL (WHOXA-OLD EXACT APPROACH) ====================
        let audioChannel = FlutterMethodChannel(
            name: "primocys.call.audio",
            binaryMessenger: controller.binaryMessenger)

        audioChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in

            switch call.method {
            // Video call: Enable speaker
            case "prepareAudioForWebRTC":
                let isVideoCall = (call.arguments as? [String: Any])?["isVideoCall"] as? Bool ?? false
                if isVideoCall {
                    self.setSpeaker()
                } else {
                    self.setEarpiece()
                }
                result(true)

            // Toggle speaker during call
            case "setSpeakerphone":
                let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
                if enabled {
                    self.setSpeaker()
                } else {
                    self.setEarpiece()
                }
                result(true)

            // Cleanup after call (release mic)
            case "forceResetAudioSessionForNextCall", "restoreNormalAudio":
                self.cleanupAudioSession()
                result(nil)

            case "playSystemRingtone":
                self.playSystemRingtone()
                result(nil)

            case "stopSystemRingtone", "stopCustomCallRingtone":
                self.stopSystemRingtone()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        })

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // =============================================================================
    // AUDIO SESSION METHODS (EXACT WHOXA-OLD STYLE)
    // =============================================================================

    // CRITICAL FIX: Don't manage AVAudioSession - WebRTC RTCAudioSession owns it!
    // ONLY change audio route, never touch category or activation
    private func setEarpiece() {
        print("🎯 Setting earpiece ROUTE ONLY (WebRTC owns session)...")
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // ONLY override route - WebRTC manages category & activation!
            try audioSession.overrideOutputAudioPort(.none)
            print("✅ Earpiece route set")
        } catch {
            print("❌ Failed to set earpiece route: \(error)")
        }
    }

    // CRITICAL FIX: Don't manage AVAudioSession - WebRTC RTCAudioSession owns it!
    private func setSpeaker() {
        print("🎯 Setting speaker ROUTE ONLY (WebRTC owns session)...")
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // ONLY override route - WebRTC manages category & activation!
            try audioSession.overrideOutputAudioPort(.speaker)
            print("✅ Speaker route set")
        } catch {
            print("❌ Failed to set speaker route: \(error)")
        }
    }

    // CRITICAL FIX: DON'T deactivate - WebRTC RTCAudioSession handles lifecycle!
    // Deactivating breaks WebRTC's audio for subsequent calls
    private func cleanupAudioSession() {
        print("🧹 Cleanup: Reset route ONLY (WebRTC owns session lifecycle)...")
        self.stopSystemRingtone()

        do {
            let audioSession = AVAudioSession.sharedInstance()
            // ONLY reset route override - DON'T deactivate!
            // WebRTC's RTCAudioSession will handle deactivation when ready
            try audioSession.overrideOutputAudioPort(.none)
            print("✅ Route reset (session stays active for WebRTC)")
        } catch {
            print("❌ Failed to reset route: \(error)")
        }
    }

    // =============================================================================
    // RINGTONE & OTHER METHODS
    // =============================================================================

    private func playSystemRingtone() {
        // CRITICAL FIX: Don't change audio session for ringtone
        // Just play the sound - iOS will handle routing
        AudioServicesPlaySystemSound(SystemSoundID(1005))
        print("✅ System ringtone playing (no session changes)")
    }

    private func stopSystemRingtone() {
        AudioServicesDisposeSystemSoundID(SystemSoundID(1005))
    }

    private func addContact(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let url = URL(string: "contacts://") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            result("Contact app opened")
        } else {
            result(FlutterError(code: "UNAVAILABLE", message: "Cannot open contacts app", details: nil))
        }
    }

    private func getRingerMode() -> String {
        let audioSession = AVAudioSession.sharedInstance()
        let outputVolume = audioSession.outputVolume
        if outputVolume == 0.0 {
            return "silent"
        }
        return "general"
    }

    private func startVibration() {
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    private func stopVibration() {
        // iOS automatically stops vibration
    }

    // =============================================================================
    // KEYCHAIN MANAGEMENT
    // =============================================================================

    private func clearFlutterSecureStorageKeychain() {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.primocys.chat"

        // Method 1: Clear all generic password items (most thorough)
        let clearAllQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        let deleteAllStatus = SecItemDelete(clearAllQuery as CFDictionary)
        print("🔑 Clear all keychain items status: \(deleteAllStatus)")

        // Method 2: Also try specific service identifiers as backup
        let serviceIdentifiers = [
            "flutter_secure_storage_service",  // Default service name used by flutter_secure_storage
            bundleId,
            "\(bundleId).flutter_secure_storage",
            "FlutterSecureStorage",
            "flutter.secure.storage",
        ]
        for serviceId in serviceIdentifiers {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceId,
            ]
            let status = SecItemDelete(query as CFDictionary)
            print("🔑 Clear keychain for service '\(serviceId)': \(status)")
        }

        print("✅ Keychain clearing completed")
    }

    private func clearAllUserDefaults() {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        for key in dictionary.keys {
            if !key.hasPrefix("Apple") && !key.hasPrefix("NS") && key != "FirstRun" {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.synchronize()
    }

    private func debugListKeychainItems() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            print("📋 Found \(items.count) keychain items")
        }
    }

    // =============================================================================
    // NOTIFICATION DELEGATE METHODS (iOS 10+)
    // =============================================================================

    // ✅ CRITICAL FIX: Handle notification when app is in foreground
    @available(iOS 10.0, *)
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("🔔 Notification received in foreground")
        print("📦 Notification content: \(notification.request.content.userInfo)")

        // Let OneSignal handle the notification
        // Show banner, sound, and badge
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    // ✅ CRITICAL FIX: Handle notification tap (including from terminated state)
    @available(iOS 10.0, *)
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("🔔 Notification tapped by user")
        print("📦 Notification content: \(response.notification.request.content.userInfo)")
        print("🎯 Action identifier: \(response.actionIdentifier)")

        // Let OneSignal handle the tap
        // The Flutter OneSignal plugin will receive this and route appropriately
        completionHandler()
    }

    // ✅ Handle remote notification when app is in background/terminated (iOS 9 style, still needed)
    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("🔔 Remote notification received")
        print("📦 Notification payload: \(userInfo)")

        // Let OneSignal handle the notification
        completionHandler(.newData)
    }
}
