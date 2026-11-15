import Foundation
import Testing
@testable import MapPilot

struct UserDefaultsRecentPlaceRepositoryTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func savesAndLoadsWithoutDistance() async {
        let defaults = makeDefaults()
        let place = Fixtures.place(id: "a")
        let usedAt = Date(timeIntervalSince1970: 1_800_000_000)

        await UserDefaultsRecentPlaceRepository(defaults: defaults).save([RecentPlace(place: place, usedAt: usedAt)])
        let loaded = await UserDefaultsRecentPlaceRepository(defaults: defaults).load()

        #expect(loaded.count == 1)
        #expect(loaded.first?.place.id == "a")
        #expect(loaded.first?.place.name == place.name)
        #expect(loaded.first?.place.location == place.location)
        // 거리는 고른 때의 내 위치 기준이라 저장하지 않는다.
        #expect(loaded.first?.place.distanceMeters == nil)
        #expect(loaded.first?.usedAt == usedAt)
    }

    @Test func brokenDataStartsEmpty() async {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: UserDefaultsRecentPlaceRepository.key)

        #expect(await UserDefaultsRecentPlaceRepository(defaults: defaults).load().isEmpty)
    }
}
