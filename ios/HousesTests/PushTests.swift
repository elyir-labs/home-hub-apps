// SPDX-License-Identifier: Apache-2.0
import CryptoKit
import XCTest
@testable import Houses

final class PushTests: XCTestCase {
    private let keys = PushKeys(privateKey: P256.KeyAgreement.PrivateKey(), auth: Data((0..<16).map { UInt8($0) }))
    private let maple = HouseRecord(id: "maple-court", name: "Mum’s", origin: URL(string: "https://maple-court.elyir.app")!, lan: nil, token: "t")

    private func notice(_ text: String = "The back door is open.", house: String? = "Maple Court", label: String? = "maple-court") -> Data {
        var row: [String: Any] = ["id": "n1", "class": "needs", "text": text, "subject": "door", "at": 1_792_000_000, "tag": "door"]
        row["house"] = house
        row["label"] = label
        return try! JSONSerialization.data(withJSONObject: row)
    }

    private func arrived(_ sealed: Data, h: String = "maple-court") -> [AnyHashable: Any] {
        ["aps": ["alert": ["title": "Houses", "body": "One of your houses needs a look."], "mutable-content": 1, "thread-id": h],
         "h": h, "s": sealed.base64URL]
    }

    // MARK: The phone's identity

    func testThePhoneMakesItsKeyOnceAndKeepsItInTheSharedKeychainGroup() throws {
        XCTAssertNotNil(Keychain.group)
        Keychain.clear(PushKeys.account)
        defer { Keychain.clear(PushKeys.account) }
        XCTAssertNil(PushKeys.load())
        let made = try XCTUnwrap(PushKeys.loadOrMake())
        let again = try XCTUnwrap(PushKeys.loadOrMake())
        let read = try XCTUnwrap(PushKeys.load())
        XCTAssertEqual(again.p256dh, made.p256dh)
        XCTAssertEqual(read.p256dh, made.p256dh)
        XCTAssertEqual(read.auth, made.auth)
        XCTAssertEqual(made.p256dh.count, 65)
        XCTAssertEqual(made.p256dh.first, 0x04)
        XCTAssertEqual(made.auth.count, 16)
    }

    func testTheIdentityIsWhereToSendAndWhatToSealTo() {
        let id = PushIdentity.make(token: Data([0xab, 0x01, 0xff]), keys: keys, env: "sandbox")
        XCTAssertEqual(id["kind"], "apns")
        XCTAssertEqual(id["token"], "ab01ff")
        XCTAssertEqual(id["env"], "sandbox")
        XCTAssertEqual(id["auth"], "AAECAwQFBgcICQoLDA0ODw")
        XCTAssertEqual(id["p256dh"].flatMap(Data.init(base64URL:)), keys.p256dh)
        XCTAssertEqual(Set(id.keys), ["kind", "token", "env", "p256dh", "auth"])
        XCTAssertEqual(PushIdentity.env, "sandbox")
    }

    // MARK: What the page is told

    func testThePageAsksForTheIdentityAndToStop() {
        XCTAssertEqual(HousesMessage.parse(["type": "houses:push-identity"]), .pushIdentity)
        XCTAssertEqual(HousesMessage.parse(["type": "houses:push-off"]), .pushOff)
    }

    func testThePageIsAnsweredWithAnEvent() {
        let id = ["kind": "apns", "token": "ab01", "env": "sandbox", "p256dh": "BA", "auth": "AA"]
        XCTAssertEqual(PushAnswer.identity(id).script,
                       #"window.dispatchEvent(new CustomEvent('houses:push-identity', {detail: {"auth":"AA","env":"sandbox","kind":"apns","p256dh":"BA","token":"ab01"}}))"#)
        XCTAssertEqual(PushAnswer.denied.script, #"window.dispatchEvent(new CustomEvent('houses:push-identity', {detail: {"denied":true}}))"#)
        XCTAssertEqual(PushAnswer.failed("no valid aps-environment entitlement").script,
                       #"window.dispatchEvent(new CustomEvent('houses:push-identity', {detail: {"error":"no valid aps-environment entitlement"}}))"#)
        XCTAssertEqual(PushAnswer.off.script, #"window.dispatchEvent(new CustomEvent('houses:push-off', {detail: {"ok":true}}))"#)
    }

    func testAReasonCannotBreakOutOfTheAnswer() {
        let script = PushAnswer.failed("'))}); alert(1); //\"").script
        XCTAssertTrue(script.hasPrefix("window.dispatchEvent(new CustomEvent('houses:push-identity', {detail: {\"error\":\"'))}); alert(1); \\/\\/\\\"\"}}))"), script)
    }

    // MARK: Opening what arrives

    func testASealedNotificationOpensWithThePhonesNameForTheHouse() throws {
        let sealed = try WebPush.seal(notice(), to: keys)
        let shown = try XCTUnwrap(Delivery.open(arrived(sealed), keys: keys, houses: [maple]))
        XCTAssertEqual(shown, Delivery.Shown(title: "Mum’s", body: "The back door is open.", thread: "maple-court"))
    }

    func testAHouseThePhoneHasNoNameForIsCalledWhatTheHouseCallsItself() throws {
        let sealed = try WebPush.seal(notice(), to: keys)
        XCTAssertEqual(Delivery.open(arrived(sealed), keys: keys, houses: [])?.title, "Maple Court")
        let unnamed = try WebPush.seal(notice(house: nil), to: keys)
        XCTAssertEqual(Delivery.open(arrived(unnamed), keys: keys, houses: [])?.title, "maple-court")
    }

    func testTheLabelInsideWinsAndTheOneBesideItStandsInWhenThereIsNone() throws {
        let other = HouseRecord(id: "elm", name: "The cabin", origin: URL(string: "https://elm.elyir.app")!, lan: nil, token: "t")
        let inside = try WebPush.seal(notice(), to: keys)
        XCTAssertEqual(Delivery.open(arrived(inside, h: "elm"), keys: keys, houses: [maple, other])?.thread, "maple-court")
        let none = try WebPush.seal(notice(label: nil), to: keys)
        XCTAssertEqual(Delivery.open(arrived(none, h: "elm"), keys: keys, houses: [maple, other]),
                       Delivery.Shown(title: "The cabin", body: "The back door is open.", thread: "elm"))
    }

    func testABodyOverSeveralRecordsOpens() throws {
        let long = String(repeating: "Something needs a look. ", count: 20)
        let sealed = try WebPush.seal(notice(long), to: keys, rs: 64)
        XCTAssertEqual(Delivery.open(arrived(sealed), keys: keys, houses: [maple])?.body, long)
    }

    /// Sealed by Python's http_ece (the library a house seals with) to a key made for this test alone.
    func testOpensWhatAnotherImplementationSealed() throws {
        let d = hex(["43520ef83eeab107", "700cf734380802e3", "f0959be9f22796ef", "eb13fa7cf47d4e54"])
        let auth = hex(["86106442a8de9b53", "09f6fd3e7ec7a352"])
        let body = hex([
            "714c50313ebed40b", "125f013853f872c4", "00001000410479e0", "6fad3486a1b58978", "e3bc2300a9f50bcd", "64c36d52d11e54cd",
            "8accc31e509071cf", "58f0137c76e9642f", "441a9e4f6f48ecb1", "7d6d30dc2a0fc47d", "d96af5edda1c1cfa", "832a41819b21b86a",
            "bf0830e17caae4a2", "65aa602bf39cbb98", "5e04f21cc705912a", "e375a274379cead6", "eea82e3eb9dc5fc0", "5d5e0d0594ddbf8c",
            "55e289fee947aa45", "68a94143a3676fb3", "ae1396d9a2058633", "fd2c46dfb92f4c1f", "6a01f7861f7e22a7", "b93dba386fdda3ee",
            "b902cfd5705e16b3", "90bbe0bfb9cfa855", "e9ece96a904692f2", "a88f1c8ba6792907", "e75dac2631233097", "ad768873082742a3",
            "761b2940360302eb", "6fcc2829",
        ])
        let theirs = PushKeys(privateKey: try P256.KeyAgreement.PrivateKey(rawRepresentation: d), auth: auth)
        let plain = try XCTUnwrap(Sealed.open(body, with: theirs))
        XCTAssertEqual(String(data: plain, encoding: .utf8),
                       #"{"id":"n1","class":"needs","text":"The back door is open.","subject":"door","house":"Maple Court","label":"maple-court","at":1792000000,"tag":"door"}"#)
        XCTAssertEqual(Delivery.open(arrived(body), keys: theirs, houses: [maple])?.title, "Mum’s")
    }

    // MARK: Anything wrong leaves the sender's plain line

    func testSealedToAnotherPhoneDoesNotOpen() throws {
        let sealed = try WebPush.seal(notice(), to: keys)
        let other = PushKeys(privateKey: P256.KeyAgreement.PrivateKey(), auth: keys.auth)
        XCTAssertNil(Sealed.open(sealed, with: other))
        let otherAuth = PushKeys(privateKey: keys.privateKey, auth: Data(repeating: 9, count: 16))
        XCTAssertNil(Sealed.open(sealed, with: otherAuth))
        XCTAssertNil(Delivery.open(arrived(sealed), keys: other, houses: [maple]))
    }

    func testATruncatedOrTamperedBodyDoesNotOpen() throws {
        let sealed = try WebPush.seal(notice(), to: keys)
        XCTAssertNotNil(Sealed.open(sealed, with: keys))
        XCTAssertNil(Sealed.open(sealed.dropLast(1), with: keys))
        XCTAssertNil(Sealed.open(sealed.prefix(86), with: keys))
        XCTAssertNil(Sealed.open(sealed.prefix(10), with: keys))
        XCTAssertNil(Sealed.open(Data(), with: keys))
        var flipped = sealed
        flipped[flipped.count - 20] ^= 1
        XCTAssertNil(Sealed.open(flipped, with: keys))
    }

    func testABadHeaderDoesNotOpen() throws {
        let sealed = try WebPush.seal(notice(), to: keys)
        var idlen = sealed
        idlen[20] = 64
        XCTAssertNil(Sealed.open(idlen, with: keys))
        var rs = sealed
        rs[16] = 0; rs[17] = 0; rs[18] = 0; rs[19] = 4
        XCTAssertNil(Sealed.open(rs, with: keys))
        var point = sealed
        point[21] = 0x05
        XCTAssertNil(Sealed.open(point, with: keys))
    }

    func testWhatIsNotANoticeOrNotThereLeavesThePlainLine() throws {
        XCTAssertNil(Delivery.open(arrived(try WebPush.seal(Data("not json".utf8), to: keys)), keys: keys, houses: [maple]))
        XCTAssertNil(Delivery.open(arrived(try WebPush.seal(notice(""), to: keys)), keys: keys, houses: [maple]))
        XCTAssertNil(Delivery.open(["h": "maple-court"], keys: keys, houses: [maple]))
        XCTAssertNil(Delivery.open(["h": "maple-court", "s": "!!!"], keys: keys, houses: [maple]))
        XCTAssertNil(Delivery.open(arrived(try WebPush.seal(notice(), to: keys)), keys: nil, houses: [maple]))
        let neither = try WebPush.seal(notice(label: nil), to: keys)
        XCTAssertNil(Delivery.open(["s": neither.base64URL], keys: keys, houses: [maple]))
    }

    // MARK: A tap opens the house

    func testATapOpensTheHouseItIsAbout() {
        XCTAssertEqual(Delivery.house(["h": "maple-court"]), "maple-court")
        XCTAssertNil(Delivery.house(["h": "../evil"]))
        XCTAssertNil(Delivery.house([:]))
        XCTAssertEqual(Shell.start(storefront: "USA", open: "maple-court").absoluteString,
                       "https://houses.elyir.app/?shell=ios&store=US&open=maple-court")
    }

    private func hex(_ parts: [String]) -> Data {
        let s = parts.joined()
        return Data(stride(from: 0, to: s.count, by: 2).map { i in
            UInt8(s[s.index(s.startIndex, offsetBy: i)..<s.index(s.startIndex, offsetBy: i + 2)], radix: 16)!
        })
    }
}

/// RFC 8291 encryption, as a house does it, so the extension's side can be tested against it. Only ever in tests.
enum WebPush {
    static func seal(_ plain: Data, to keys: PushKeys, rs: Int = 4096) throws -> Data {
        let sender = P256.KeyAgreement.PrivateKey()
        let senderKey = sender.publicKey.x963Representation
        let phone = try P256.KeyAgreement.PublicKey(x963Representation: keys.p256dh)
        let shared = try sender.sharedSecretFromKeyAgreement(with: phone)
        let ikm = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: keys.auth,
                                                 sharedInfo: Data("WebPush: info\0".utf8) + keys.p256dh + senderKey, outputByteCount: 32)
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        let cek = HKDF<SHA256>.deriveKey(inputKeyMaterial: ikm, salt: salt, info: Data("Content-Encoding: aes128gcm\0".utf8), outputByteCount: 16)
        let nonce = HKDF<SHA256>.deriveKey(inputKeyMaterial: ikm, salt: salt, info: Data("Content-Encoding: nonce\0".utf8), outputByteCount: 12)
            .withUnsafeBytes { [UInt8]($0) }

        var out = salt + Data([UInt8(rs >> 24 & 0xff), UInt8(rs >> 16 & 0xff), UInt8(rs >> 8 & 0xff), UInt8(rs & 0xff), 65]) + senderKey
        let size = rs - 17
        let chunks = plain.isEmpty ? [Data()] : stride(from: 0, to: plain.count, by: size).map { Data(plain[$0..<min($0 + size, plain.count)]) }
        for (seq, chunk) in chunks.enumerated() {
            var n = nonce
            for i in 0..<8 { n[11 - i] ^= UInt8(truncatingIfNeeded: UInt64(seq) >> (8 * UInt64(i))) }
            let delimiter: UInt8 = seq == chunks.count - 1 ? 2 : 1
            let box = try AES.GCM.seal(chunk + [delimiter], using: cek, nonce: AES.GCM.Nonce(data: n))
            out += box.ciphertext + box.tag
        }
        return out
    }
}
