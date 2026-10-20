// SPDX-License-Identifier: Apache-2.0
/*
 What the shell owes the Houses app (docs/apps.md in the hub's repository, "What the shell owes the page"):
 where it opens, what it says about the store it came from, and which links leave for the system browser.
 Kept free of UIKit so the rules can be tested on their own.
 */
import Foundation

enum Shell {
    static let houses = URL(string: "https://houses.elyir.app/")!

    /// The address the app opens. StoreKit names the storefront in three letters; the page wants two, and a
    /// storefront it cannot read counts as not the US (design/store-app/, C), so an unknown one is left off.
    static func start(at base: URL = houses, storefront: String?) -> URL {
        var parts = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        var query = parts.queryItems ?? []
        query.append(URLQueryItem(name: "shell", value: "ios"))
        if let store = storefront.flatMap(twoLetters) { query.append(URLQueryItem(name: "store", value: store)) }
        parts.queryItems = query
        return parts.url!
    }

    /// Only the storefronts the page treats differently need to be told apart; every other one is simply not the US.
    static func twoLetters(_ storefront: String) -> String? {
        let code = storefront.uppercased()
        if code.count == 2 { return code }
        return ["USA": "US"][code]
    }

    /// Whether a navigation leaves the app for the system browser. The Houses app and the houses it frames stay;
    /// a page opened toward anywhere else (paying, a help page) goes out, and so does anything that isn't the web.
    static func opensOutside(_ url: URL, mainFrame: Bool, home: URL = houses) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return url.scheme != "about" }
        if !mainFrame { return false }
        return url.host?.lowercased() != home.host?.lowercased() || url.port != home.port
    }
}
