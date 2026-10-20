// SPDX-License-Identifier: Apache-2.0
/*
 Opens a sealed notification on the phone before it is shown. What arrives says only "One of your houses needs a
 look"; this puts the phone's own name for the house on it and what the house said. If anything is wrong, the plain
 line is shown as it came.
 */
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var handler: ((UNNotificationContent) -> Void)?
    private var original: UNNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler handler: @escaping (UNNotificationContent) -> Void) {
        self.handler = handler
        original = request.content
        guard let shown = Delivery.open(request.content.userInfo, keys: PushKeys.load(), houses: HouseStore.houses()),
              let content = request.content.mutableCopy() as? UNMutableNotificationContent
        else { return deliver(request.content) }
        content.title = shown.title
        content.body = shown.body
        content.threadIdentifier = shown.thread
        deliver(content)
    }

    override func serviceExtensionTimeWillExpire() {
        if let original { deliver(original) }
    }

    private func deliver(_ content: UNNotificationContent) {
        handler?(content)
        handler = nil
    }
}
