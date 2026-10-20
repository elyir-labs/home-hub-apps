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

| | |
|---|---|
| `ios/` | Swift, iOS 17 and later, with the widget. `open ios/Houses.xcodeproj` |
| `android/` | Not yet. Will start from the hub's wall kiosk (`kiosk/` there) |

Licensed under Apache-2.0 (`LICENSE`). The names and icons are not (`NOTICE`).
