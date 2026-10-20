// SPDX-License-Identifier: Apache-2.0
/*
 Notifications in the store app (docs/apps.md in the hub's repository: the store app's notifications come through a
 sender Elyir runs, and it only ever carries sealed ones). A house seals each notification to a key only this phone
 holds, exactly as web push does (RFC 8291), and hands it to the sender with this phone's APNs token. The sender and
 Apple carry it without being able to read it; HousesNotify opens it here and puts the phone's own name for the house
 on it. Kept free of UIKit and of the extension so every case can be tested on its own.
 */
import CryptoKit
import Security
import UserNotifications
import Foundation

/// The phone's key for sealed notifications and the secret that goes with it. Made once, kept in the keychain group
/// the app shares with its extensions, readable after the first unlock so a notification can be opened on a locked
/// phone, and never carried to another device. Only the public half and the secret are ever handed to a house.
struct PushKeys {
    let privateKey: P256.KeyAgreement.PrivateKey
    let auth: Data

    var p256dh: Data { privateKey.publicKey.x963Representation }

    static let account = "push"

    static func load() -> PushKeys? {
        guard let data = Keychain.read(account), data.count == 48,
              let key = try? P256.KeyAgreement.PrivateKey(rawRepresentation: data.prefix(32))
        else { return nil }
        return PushKeys(privateKey: key, auth: Data(data.suffix(16)))
    }

    /// The phone's keys, made on first ask. Nil only when the keychain will not keep them.
    static func loadOrMake() -> PushKeys? {
        if let kept = load() { return kept }
        var auth = Data(count: 16)
        guard auth.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }) == errSecSuccess
        else { return nil }
        let made = PushKeys(privateKey: P256.KeyAgreement.PrivateKey(), auth: auth)
        guard Keychain.write(made.privateKey.rawRepresentation + auth, account: account) else { return nil }
        return made
    }
}

/// What the page is handed when it asks for this phone's push identity: where to send (the APNs token, and which of
/// Apple's two services it belongs to) and what to seal to.
enum PushIdentity {
    /// A build run from Xcode gets sandbox tokens; one from the store, production ones.
    static var env: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    static func make(token: Data, keys: PushKeys, env: String = env) -> [String: String] {
        ["kind": "apns",
         "token": token.map { String(format: "%02x", $0) }.joined(),
         "env": env,
         "p256dh": keys.p256dh.base64URL,
         "auth": keys.auth.base64URL]
    }
}

/// RFC 8291 message decryption: an aes128gcm body (RFC 8188) sealed to the phone's key with its auth secret.
enum Sealed {
    static func open(_ body: Data, with keys: PushKeys) -> Data? {
        let body = Data([UInt8](body))
        guard body.count > 21 else { return nil }
        let salt = body.prefix(16)
        let rs = body[16..<20].reduce(0) { $0 << 8 | Int($1) }
        let idlen = Int(body[20])
        guard rs >= 18, idlen == 65, body.count > 21 + idlen else { return nil }
        let senderKey = body[21..<(21 + idlen)]
        guard let sender = try? P256.KeyAgreement.PublicKey(x963Representation: senderKey),
              let shared = try? keys.privateKey.sharedSecretFromKeyAgreement(with: sender)
        else { return nil }

        let keyInfo = Data("WebPush: info\0".utf8) + keys.p256dh + senderKey
        let ikm = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: keys.auth, sharedInfo: keyInfo, outputByteCount: 32)
        let cek = HKDF<SHA256>.deriveKey(inputKeyMaterial: ikm, salt: salt, info: Data("Content-Encoding: aes128gcm\0".utf8), outputByteCount: 16)
        let nonce = HKDF<SHA256>.deriveKey(inputKeyMaterial: ikm, salt: salt, info: Data("Content-Encoding: nonce\0".utf8), outputByteCount: 12)
            .withUnsafeBytes { Data($0) }

        let records = body.suffix(from: 21 + idlen)
        var plain = Data()
        var start = records.startIndex
        var seq: UInt64 = 0
        while start < records.endIndex {
            let end = min(start + rs, records.endIndex)
            let record = records[start..<end]
            let last = end == records.endIndex
            guard record.count > 16,
                  let box = try? AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: xor(nonce, seq)), ciphertext: record.dropLast(16), tag: record.suffix(16)),
                  let opened = try? AES.GCM.open(box, using: cek),
                  let unpadded = unpad(opened, last: last)
            else { return nil }
            plain += unpadded
            start = end
            seq += 1
        }
        return plain
    }

    /// Each record ends in a delimiter, 2 on the last and 1 on any other, followed only by zeros.
    private static func unpad(_ record: Data, last: Bool) -> Data? {
        guard let at = record.lastIndex(where: { $0 != 0 }), record[at] == (last ? 2 : 1) else { return nil }
        return record[record.startIndex..<at]
    }

    private static func xor(_ nonce: Data, _ seq: UInt64) -> Data {
        var out = [UInt8](nonce)
        for i in 0..<8 { out[out.count - 1 - i] ^= UInt8(truncatingIfNeeded: seq >> (8 * UInt64(i))) }
        return Data(out)
    }
}

/// What a house sealed: `{id, class, text, subject, house, label, at, tag}`. Only what goes on the notification is read.
struct Notice: Decodable, Equatable {
    let text: String
    let house: String?
    let label: String?
}

/// How a sealed notification reads on this phone: titled with the phone's own name for the house, saying what the
/// house said, and grouped by house. Nil when anything is wrong, and then the sender's own plain line stands.
enum Delivery {
    struct Shown: Equatable { let title: String; let body: String; let thread: String }

    static func open(_ userInfo: [AnyHashable: Any], keys: PushKeys?, houses: [HouseRecord]) -> Shown? {
        guard let keys, let sealed = (userInfo["s"] as? String).flatMap(Data.init(base64URL:)),
              let plain = Sealed.open(sealed, with: keys),
              let notice = try? JSONDecoder().decode(Notice.self, from: plain),
              !notice.text.isEmpty,
              let label = notice.label.flatMap({ HouseLink.isID($0) ? $0 : nil }) ?? house(userInfo)
        else { return nil }
        let name = houses.first { $0.id == label }?.name.nonEmpty ?? notice.house?.nonEmpty ?? label
        return Shown(title: name, body: notice.text, thread: label)
    }

    /// What HousesNotify shows for a notification: the sealed part opened onto it, everything else as it came.
    static func content(of request: UNNotificationRequest, keys: PushKeys?, houses: [HouseRecord]) -> UNNotificationContent {
        guard let shown = open(request.content.userInfo, keys: keys, houses: houses),
              let content = request.content.mutableCopy() as? UNMutableNotificationContent
        else { return request.content }
        content.title = shown.title
        content.body = shown.body
        content.threadIdentifier = shown.thread
        return content
    }

    /// The house a notification is about, from the label beside the sealed part: what a tap opens.
    static func house(_ userInfo: [AnyHashable: Any]) -> String? {
        (userInfo["h"] as? String).flatMap { HouseLink.isID($0) ? $0 : nil }
    }
}

extension Data {
    init?(base64URL s: String) {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        b += String(repeating: "=", count: (4 - b.count % 4) % 4)
        self.init(base64Encoded: b)
    }

    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
