# Elyir Home Hub apps

The phone apps for [Elyir Home Hub](https://hub.elyir.com). Each one is a native shell around the Houses app at
`houses.elyir.app`. The house's own panel comes from the house and never from the app, so a house never runs a
panel older than its hub, and an app update never waits on a review to reach one.

What the shells owe the page, and why they are shells, is decided in the hub's repository:
[`docs/apps.md`](https://github.com/elyir-labs/home-hub/blob/development/docs/apps.md). In short:

- The app opens `https://houses.elyir.app/?shell=ios&store=US` (`shell=android` on Android), with the storefront
  as two letters, or with no `store` when it cannot tell. The page decides what the stores allow from that
  (`design/store-app/`, C).
- Anything opened toward somewhere other than the Houses app (paying, a help page) goes to the system browser.
  Paying never happens inside the app.
- Nothing here draws a house. If a screen of the house needs changing, it changes in the hub's repository.

## The widget

One widget, decided on 20 October 2026 in the hub's `design/widget/`: the small size says how a house is (its name,
its weather, and the line Houses says for it, in the lamp when something needs a look), and the medium size adds
Bedtime and Everything off. A tap on either button runs it on the house; a tap anywhere else opens that house in
the app. Each widget is set to one house when it is added, and starts on the house last opened. iOS:
`ios/HousesWidget/`, with what it says worked out in `ios/Shared/` and tested in `ios/HousesTests/WidgetTests.swift`.

It asks the house itself and never a server of ours, which takes three things from the Houses app and the house:

- **The list.** Inside the app the Houses app posts `{type: 'houses:list', houses: [{id, name, origin, lan, token}]}`
  to `window.webkit.messageHandlers.houses` when it loads and whenever the list changes, and
  `{type: 'houses:opened', id}` when a house is opened. Only the Houses app's own page is believed (its main frame,
  on its own host). The list, with each house's pass, is kept in a keychain group the app and the widget share; a
  house the list no longer has is forgotten, with its last glance.
- **The glance.** `GET {base}/glance` with `Authorization: Bearer <token>` answers
  `{name, temp, sky, said: [one or two lines], needs, count, at}`. The base is `https://<lan>` when `/alive` answers
  there within a second and a half, else the house's own address: the Houses app's rule. Asked about every quarter
  of an hour; when the house does not answer, the widget shows the last glance and how old it is.
- **The two words.** `POST {base}/home/intent/asleep` (Bedtime) and `/home/intent/away` (Everything off), with the
  same pass. Until its next refresh the widget then says the panel's own words, or that it couldn't reach the house.

A tap opens `houses://open/<id>`, and the app opens `https://houses.elyir.app/?shell=ios&store=US&open=<id>`.

## Notifications (iOS)

A house's notifications reach the store app through a sender Elyir runs, and the sender only ever carries sealed
ones (decided 19 October 2026 in the hub's `docs/apps.md`). The phone makes a key once and keeps it in the keychain
group it shares with its extensions; a house seals each notification to it the way web push does (RFC 8291,
aes128gcm). What Apple delivers says only *One of your houses needs a look*; `ios/HousesNotify/`, a notification
service extension, opens it on the phone, titles it with the phone's own name for the house and says what the house
said. If anything is wrong it leaves the plain line. A tap opens that house
(`https://houses.elyir.app/?shell=ios&store=US&open=<label>`).

- **The page asks** `{type: 'houses:push-identity'}` on the same `houses` handler, from its own main frame only. The
  app asks the person, registers with Apple, and answers with an event, `houses:push-identity`, whose `detail` is
  `{kind: "apns", token, env: "sandbox" | "production", p256dh, auth}`, or `{denied: true}`, or `{error}`.
  `{type: 'houses:push-off'}` is answered with `houses:push-off`, `{ok: true}`; the houses are told by the page.
- **What arrives** is `{"aps": {"alert": {...}, "mutable-content": 1, "thread-id": <house>}, "h": <label>, "s": <sealed, base64url>}`,
  and the sealed part is `{id, class, text, subject, house, label, at, tag}`.

The simulator gets a real sandbox token, but `xcrun simctl push` hands a notification straight to the home screen
without running the service extension, so on a simulator it shows the plain line; the opening is tested in
`ios/HousesTests/PushTests.swift`, including against a body sealed by Python's `http_ece`. A real phone needs the
team's Push Notifications capability on `app.elyir.houses` (with the App Group and keychain group for
`app.elyir.houses.notify`), and the sender needs Elyir's APNs key, which is not configured yet.

| | |
|---|---|
| `ios/` | Swift, iOS 17 and later, with the widget and notifications. `open ios/Houses.xcodeproj` |
| `android/` | Kotlin, Android 8 and later. See below |

Both start with J, drawn by the app from `startup.json` (`tools/startup.sh <hub checkout>` copies it from the hub's
`startup/sequence.json` into both apps).

## Android

A Gradle project started from the hub's wall kiosk (`kiosk/` there), with JDK 17 or later and the Android SDK:

```sh
cd android
export ANDROID_HOME=~/Library/Android/sdk
./gradlew test assembleDebug lint
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

A debug build can be pointed at the Houses app's dev server, which the emulator reaches as `10.0.2.2`, the way the
iOS scheme's `-houses` argument does it. It is kept until it is cleared with `-e houses ""`:

```sh
adb shell am start -n app.elyir.houses/.Houses -e houses http://10.0.2.2:5174/
```

Only a debug build may use plain http, and only to `10.0.2.2` and `localhost`. The page's camera needs a secure
page, so for reading a code on an emulator use `adb reverse tcp:5174 tcp:5174` and `http://localhost:5174/`.

Licensed under Apache-2.0 (`LICENSE`). The names and icons are not (`NOTICE`).
