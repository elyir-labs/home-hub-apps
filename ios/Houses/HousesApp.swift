// SPDX-License-Identifier: Apache-2.0
import StoreKit
import SwiftUI

@main
struct HousesApp: App {
    var body: some Scene {
        WindowGroup { ShellView() }
    }
}

/// The Houses app, edge to edge, on the panel's own night. It waits for the storefront before loading, so the
/// first page already knows what the store allows; a store that does not answer quickly is treated as unknown.
struct ShellView: View {
    @State private var start: URL?

    var body: some View {
        ZStack {
            Color("Night").ignoresSafeArea()
            if let start { HousesWebView(start: start, home: Self.home).ignoresSafeArea() }
        }
        .task {
            let store = await withTaskGroup(of: String?.self) { group in
                group.addTask { await Storefront.current?.countryCode }
                group.addTask { try? await Task.sleep(for: .seconds(1.5)); return nil }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
            start = Shell.start(at: Self.home, storefront: store)
        }
    }

    /// `-houses http://localhost:5174/` on the scheme's arguments points a simulator at the Houses app's dev server.
    static var home: URL {
        UserDefaults.standard.string(forKey: "houses").flatMap(URL.init(string:)) ?? Shell.houses
    }
}
