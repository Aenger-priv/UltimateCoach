import AudioToolbox
import OSLog
import UIKit
import UserNotifications

final class RestWhistle: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    nonisolated private static let identifier = "rest-whistle"
    private static let filename = "rest-whistle.wav"

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    static func authorize() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func schedule(for deadline: Date?) {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        guard let interval = deadline?.timeIntervalSinceNow, interval > 0 else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(filename))
        // Adding a request with the same identifier replaces the previous deadline.
        let request = UNNotificationRequest(identifier: identifier, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
        center.add(request) { error in
            if let error { Logger(subsystem: "UltimateCoach", category: "Rest").error("Whistle scheduling failed: \(error)") }
        }
    }

    private static let previewSound: SystemSoundID? = {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else { return nil }
        var sound: SystemSoundID = 0
        return AudioServicesCreateSystemSoundID(url as CFURL, &sound) == kAudioServicesNoError ? sound : nil
    }()

    static func preview() {
        if let previewSound { AudioServicesPlaySystemSound(previewSound) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                           willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        notification.request.identifier == Self.identifier ? [.sound] : []
    }
}
