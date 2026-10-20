// SPDX-License-Identifier: Apache-2.0
/*
 Where the app leaves the houses for the widget. The list, with each house's pass, is in the keychain under an access
 group the app and the widget share, readable after the phone's first unlock so a widget can refresh on a locked
 phone, and never carried to another device. What is not a secret (the house last opened, each house's last glance,
 a tap on a button) is in the App Group's defaults. The phone's key for sealed notifications sits beside the list, under
 its own name, so the notification extension can open what arrives (Push.swift).
 */
import Foundation
import Security

enum HouseStore {
    static let group = "group.app.elyir.houses"
    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    static func houses() -> [HouseRecord] {
        guard let data = Keychain.read() else { return [] }
        return (try? JSONDecoder().decode([HouseRecord].self, from: data)) ?? []
    }

    /// Keeps the list the Houses app sent, and forgets everything about a house it no longer has. Whether anything changed.
    @discardableResult
    static func save(_ list: [HouseRecord]) -> Bool {
        let before = houses()
        guard list != before else { return false }
        guard let data = try? JSONEncoder().encode(list), Keychain.write(data) else { return false }
        let ids = Set(list.map(\.id))
        for gone in before.map(\.id) where !ids.contains(gone) {
            defaults.removeObject(forKey: glanceKey(gone))
            defaults.removeObject(forKey: tapKey(gone))
        }
        if let opened, !ids.contains(opened) { defaults.removeObject(forKey: openedKey) }
        return true
    }

    static var opened: String? {
        get { defaults.string(forKey: openedKey) }
        set { defaults.set(newValue, forKey: openedKey) }
    }

    static func kept(_ id: String) -> Kept? { read(Kept.self, glanceKey(id)) }
    static func keep(_ glance: Glance, for id: String, at now: Date = .now) { write(Kept(glance: glance, got: now), glanceKey(id)) }

    static func tap(_ id: String) -> Tap? { read(Tap.self, tapKey(id)) }
    static func keep(_ tap: Tap) { write(tap, tapKey(tap.id)) }

    private static let openedKey = "opened"
    private static func glanceKey(_ id: String) -> String { "glance.\(id)" }
    private static func tapKey(_ id: String) -> String { "tap.\(id)" }

    private static func read<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
    private static func write<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}

enum Keychain {
    /// `$(AppIdentifierPrefix)app.elyir.houses.shared`, from each target's Info.plist, so it carries the team's prefix.
    static var group: String? { Bundle.main.object(forInfoDictionaryKey: "HousesKeychainGroup") as? String }

    private static func query(_ account: String) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: "app.elyir.houses",
                                kSecAttrAccount as String: account]
        if let group, !group.isEmpty { q[kSecAttrAccessGroup as String] = group }
        return q
    }

    static func read(_ account: String = "houses") -> Data? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }

    @discardableResult
    static func write(_ data: Data, account: String = "houses") -> Bool {
        let attrs: [String: Any] = [kSecValueData as String: data,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query(account) as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            return SecItemAdd(query(account).merging(attrs) { $1 } as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    static func clear(_ account: String = "houses") { SecItemDelete(query(account) as CFDictionary) }
}
