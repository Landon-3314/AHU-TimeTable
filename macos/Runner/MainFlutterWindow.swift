import Cocoa
import FlutterMacOS
import UserNotifications

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    TimetablePlatformChannels.register(
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    super.awakeFromNib()
  }
}

final class TimetablePlatformChannels {
  private static let nativeAlarmChannelName = "com.timetable/native_alarm"
  private static let permissionsChannelName = "app.permissions"
  private static let timezoneChannelName = "app.timezone"
  private static let notificationIdentifierPrefix = "timetable.reminder."

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let timeZoneChannel = FlutterMethodChannel(
      name: timezoneChannelName,
      binaryMessenger: binaryMessenger
    )
    timeZoneChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getLocalTimezone":
        result(TimeZone.current.identifier)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let permissionsChannel = FlutterMethodChannel(
      name: permissionsChannelName,
      binaryMessenger: binaryMessenger
    )
    permissionsChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "hasNotificationPermission":
        hasNotificationPermission(result: result)
      case "requestNotificationPermission":
        requestNotificationPermission(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let nativeAlarmChannel = FlutterMethodChannel(
      name: nativeAlarmChannelName,
      binaryMessenger: binaryMessenger
    )
    nativeAlarmChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "scheduleAllClasses":
        let args = call.arguments as? [String: Any]
        let classes = args?["classes"] as? [[String: Any]] ?? []
        scheduleReminderNotifications(classes: classes, result: result)
      case "cancelAllClasses":
        cancelReminderNotifications {
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

  private static func hasNotificationPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let granted = settings.authorizationStatus == .authorized ||
        settings.authorizationStatus == .provisional
      DispatchQueue.main.async {
        result(granted)
      }
    }
  }

  private static func requestNotificationPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
      DispatchQueue.main.async {
        result(granted)
      }
    }
  }

  private static func scheduleReminderNotifications(
    classes: [[String: Any]],
    result: @escaping FlutterResult
  ) {
    cancelReminderNotifications {
      addReminderNotifications(classes: classes, result: result)
    }
  }

  private static func addReminderNotifications(
    classes: [[String: Any]],
    result: @escaping FlutterResult
  ) {
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

  private static func intValue(_ rawValue: Any?) -> Int? {
    if let value = rawValue as? Int {
      return value
    }
    if let value = rawValue as? NSNumber {
      return value.intValue
    }
    return nil
  }

  private static func doubleValue(_ rawValue: Any?) -> Double? {
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

  private static func cancelReminderNotifications(completion: (() -> Void)? = nil) {
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
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
