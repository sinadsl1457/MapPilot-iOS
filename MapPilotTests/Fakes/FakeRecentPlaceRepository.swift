import Foundation
@testable import MapPilot

actor FakeRecentPlaceRepository: RecentPlaceRepository {
    private(set) var stored: [RecentPlace]

    init(_ stored: [RecentPlace] = []) {
        self.stored = stored
    }

    func load() async -> [RecentPlace] {
        stored
    }

    func save(_ places: [RecentPlace]) async {
        stored = places
    }
}
