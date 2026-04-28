import Flutter
import UIKit
import flutter_local_notifications
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let nativeAlarmChannelName = "com.timetable/native_alarm"
  private let permissionsChannelName = "app.permissions"
  private let timezoneChannelName = "app.timezone"
  private let notificationIdentifierPrefix = "timetable.reminder."

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: self)
    let registrar = self.registrar(forPlugin: "TimetablePlatformChannels")
    registerPlatformChannels(binaryMessenger: registrar.messenger())
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TimetablePlatformChannels")
    registerPlatformChannels(binaryMessenger: registrar.messenger())
  }

  private func registerPlatformChannels(binaryMessenger: FlutterBinaryMessenger) {
    let timeZoneChannel = FlutterMethodChannel(name: timezoneChannelName, binaryMessenger: binaryMessenger)

    timeZoneChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getLocalTimezone":
        result(TimeZone.current.identifier)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let permissionsChannel = FlutterMethodChannel(name: permissionsChannelName, binaryMessenger: binaryMessenger)
    permissionsChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(false)
        return
      }
      switch call.method {
      case "hasNotificationPermission":
        self.hasNotificationPermission(result: result)
      case "requestNotificationPermission":
        self.requestNotificationPermission(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let nativeAlarmChannel = FlutterMethodChannel(name: nativeAlarmChannelName, binaryMessenger: binaryMessenger)
    nativeAlarmChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(false)
        return
      }
      switch call.method {
      case "scheduleAllClasses":
        let args = call.arguments as? [String: Any]
        let classes = args?["classes"] as? [[String: Any]] ?? []
        self.scheduleReminderNotifications(classes: classes, result: result)
      case "cancelAllClasses":
        self.cancelReminderNotifications {
          result(true)
        }
      case "hasExactAlarmPermission", "requestExactAlarmPermission",
           "isIgnoringBatteryOptimizations", "requestIgnoreBatteryOptimizations",
           "setForegroundServiceEnabled", "refreshForegroundService",
           "runOneMinuteMuteTest":
        result(true)
      case "openRomPermissionSettings":
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func hasNotificationPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      var granted = settings.authorizationStatus == .authorized ||
        settings.authorizationStatus == .provisional
      if #available(iOS 14.0, *) {
        granted = granted || settings.authorizationStatus == .ephemeral
      }
      DispatchQueue.main.async {
        result(granted)
      }
    }
  }

  private func requestNotificationPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
      DispatchQueue.main.async {
        result(granted)
      }
    }
  }

  private func scheduleReminderNotifications(classes: [[String: Any]], result: @escaping FlutterResult) {
    cancelReminderNotifications { [weak self] in
      guard let self = self else {
        result(false)
        return
      }
      self.addReminderNotifications(classes: classes, result: result)
    }
  }

  private func addReminderNotifications(classes: [[String: Any]], result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    var pendingCount = 0

    for item in classes {
      guard let index = intValue(item["courseIndex"]),
            let reminderAtMillis = doubleValue(item["reminderAtMillis"]) else {
        continue
      }

      let triggerDate = Date(timeIntervalSince1970: reminderAtMillis / 1000.0)
      guard triggerDate > Date() else {
        continue
      }

      let content = UNMutableNotificationContent()
      content.title = item["title"] as? String ?? "提醒"
      content.body = item["content"] as? String ?? "时间到了"
      content.sound = .default

      let components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute, .second],
        from: triggerDate
      )
      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      let identifier = "\(notificationIdentifierPrefix)\(index)"
      let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
      pendingCount += 1
      center.add(request) { error in
        if let error = error {
          NSLog("Failed to schedule timetable reminder: \(error.localizedDescription)")
        }
      }
    }

    result(pendingCount)
  }

  private func intValue(_ rawValue: Any?) -> Int? {
    if let value = rawValue as? Int {
      return value
    }
    if let value = rawValue as? NSNumber {
      return value.intValue
    }
    return nil
  }

  private func doubleValue(_ rawValue: Any?) -> Double? {
    if let value = rawValue as? Double {
      return value
    }
    if let value = rawValue as? Int {
      return Double(value)
    }
    if let value = rawValue as? NSNumber {
      return value.doubleValue
    }
    return nil
  }

  private func cancelReminderNotifications(completion: (() -> Void)? = nil) {
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { [notificationIdentifierPrefix] requests in
      let identifiers = requests
        .map { $0.identifier }
        .filter { $0.hasPrefix(notificationIdentifierPrefix) }
      center.removePendingNotificationRequests(withIdentifiers: identifiers)
      DispatchQueue.main.async {
        completion?()
      }
    }
  }
}
