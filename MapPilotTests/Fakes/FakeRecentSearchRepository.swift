import Foundation
@testable import MapPilot

actor FakeRecentSearchRepository: RecentSearchRepository {
    private(set) var stored: [String]

    init(_ stored: [String] = []) {
        self.stored = stored
    }

    func load() async -> [String] { stored }
    func save(_ queries: [String]) async { stored = queries }
}
