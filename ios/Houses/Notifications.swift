// SPDX-License-Identifier: Apache-2.0
/*
 The app's half of notifications: when the Houses app asks for this phone's push identity, ask the person, register
 with Apple, and answer the page with where to send and what to seal to (Push.swift). A tap on a notification opens
 its house.
 */
import os
import SwiftUI
import UIKit
import UserNotifications

/// What the page is told, as the event it listens for. Built as JSON so nothing in it is read as script.
enum PushAnswer: Equatable {
    case identity([String: String])
    case denied
    case failed(String)
    case off

    var event: String { self == .off ? "houses:push-off" : "houses:push-identity" }

    var detail: [String: Any] {
        switch self {
        case .identity(let identity): identity
        case .denied: ["denied": true]
        case .failed(let reason): ["error": reason]
        case .off: ["ok": true]
        }
    }

    var script: String {
        let json = (try? JSONSerialization.data(withJSONObject: detail, options: [.sortedKeys])).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "window.dispatchEvent(new CustomEvent('\(event)', {detail: \(json)}))"
    }
}

/// Asks once at a time: a second ask while Apple has not answered waits for the same token.
@MainActor
final class PushRegistration {
    static let shared = PushRegistration()
    static let wait: Duration = .seconds(20)

    private var waiting: [CheckedContinuation<Result<Data, PushFailure>, Never>] = []
    private var round = 0

    func identity() async -> PushAnswer {
        guard let keys = PushKeys.loadOrMake() else { return .failed("This phone would not keep the key.") }
        #if DEBUG
        Logger(subsystem: "app.elyir.houses", category: "push")
            .debug("push keys p256dh=\(keys.p256dh.base64URL, privacy: .public) auth=\(keys.auth.base64URL, privacy: .public)")
        #endif
        let center = UNUserNotificationCenter.current()
        let allowed = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard allowed else { return .denied }
        switch await token() {
        case .success(let token): return .identity(PushIdentity.make(token: token, keys: keys))
        case .failure(let failure): return .failed(failure.reason)
        }
    }

    private func token() async -> Result<Data, PushFailure> {
        await withCheckedContinuation { continuation in
            waiting.append(continuation)
            guard waiting.count == 1 else { return }
            round += 1
            let asked = round
            UIApplication.shared.registerForRemoteNotifications()
            Task { [weak self] in
                try? await Task.sleep(for: Self.wait)
                guard let self, self.round == asked else { return }
                self.finish(.failure(PushFailure(reason: "Apple did not answer.")))
            }
        }
    }

    func finish(_ result: Result<Data, PushFailure>) {
        round += 1
        let all = waiting
        waiting = []
        all.forEach { $0.resume(returning: result) }
    }
}

struct PushFailure: Error {
    let reason: String
}

/// A notification tapped: which house to open, counted so the same house twice still goes there.
struct HouseAsk: Equatable {
    let id: String
    let n: Int
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, ObservableObject {
    @Published var ask: HouseAsk?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        Task { @MainActor in PushRegistration.shared.finish(.success(token)) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        let reason = error.localizedDescription
        Task { @MainActor in PushRegistration.shared.finish(.failure(PushFailure(reason: reason))) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    @MainActor
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let id = Delivery.house(response.notification.request.content.userInfo) else { return }
        ask = HouseAsk(id: id, n: (ask?.n ?? 0) + 1)
    }
}
