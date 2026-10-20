// SPDX-License-Identifier: Apache-2.0
/*
 Opens a sealed notification on the phone before it is shown. What arrives says only "One of your houses needs a
 look"; this puts the phone's own name for the house on it and what the house said (Delivery in Shared/Push.swift).
 If anything is wrong, or time runs out, the plain line is shown as it came.
 */
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var handler: ((UNNotificationContent) -> Void)?
    private var original: UNNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler handler: @escaping (UNNotificationContent) -> Void) {
        self.handler = handler
        original = request.content
        deliver(Delivery.content(of: request, keys: PushKeys.load(), houses: HouseStore.houses()))
    }

    override func serviceExtensionTimeWillExpire() {
        if let original { deliver(original) }
    }

    private func deliver(_ content: UNNotificationContent) {
        handler?(content)
        handler = nil
    }
}
