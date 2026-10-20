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

| | |
|---|---|
| `ios/` | Swift, iOS 17 and later. `open ios/Houses.xcodeproj` |
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
