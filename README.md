# Elyir Home Hub apps

The phone apps for [Elyir Home Hub](https://hub.elyir.com). Each one is a native shell around the Houses app at
`houses.elyir.app`. The house's own panel comes from the house and never from the app, so a house never runs a
panel older than its hub, and an app update never waits on a review to reach one.

What the shells owe the page, and why they are shells, is decided in the hub's repository:
[`docs/apps.md`](https://github.com/elyir-labs/home-hub/blob/development/docs/apps.md). In short:

- The app opens `https://houses.elyir.app/?shell=ios&store=US`, with the storefront as two letters, or with no
  `store` when it cannot tell. The page decides what the stores allow from that (`design/store-app/`, C).
- Anything opened toward somewhere other than the Houses app (paying, a help page) goes to the system browser.
  Paying never happens inside the app.
- Nothing here draws a house. If a screen of the house needs changing, it changes in the hub's repository.

| | |
|---|---|
| `ios/` | Swift, iOS 17 and later. `open ios/Houses.xcodeproj` |
| `android/` | Not yet. Will start from the hub's wall kiosk (`kiosk/` there) |

Licensed under Apache-2.0 (`LICENSE`). The names and icons are not (`NOTICE`).
