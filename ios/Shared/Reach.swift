// SPDX-License-Identifier: Apache-2.0
/*
 The widget asks the house itself, with the pass the Houses app holds for it, and never a server of ours: its Wi-Fi
 name at home, its own address away.
 */
import Foundation

enum HouseClient {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 10
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static func base(_ house: HouseRecord) async -> URL {
        guard let lan = Base.lan(house) else { return house.origin }
        var request = URLRequest(url: Base.url(lan, "alive"), timeoutInterval: Base.lanWait)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let answered = (try? await session.data(for: request)).map { ($0.1 as? HTTPURLResponse)?.statusCode == 200 } ?? false
        return Base.choose(house, lanAnswered: answered)
    }

    static func glance(_ house: HouseRecord) async throws -> Glance {
        let base = await base(house)
        let (data, response) = try await session.data(for: request(Base.url(base, "glance"), house))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Glance.self, from: data)
    }

    static func run(_ scene: HouseScene, in house: HouseRecord) async -> Bool {
        let base = await base(house)
        var req = request(Base.url(base, scene.path), house)
        req.httpMethod = "POST"
        guard let (_, response) = try? await session.data(for: req) else { return false }
        return (200..<300).contains((response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private static func request(_ url: URL, _ house: HouseRecord) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("Bearer \(house.token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }
}
