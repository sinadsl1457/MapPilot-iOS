import Foundation
import Testing
@testable import MapPilot

struct UserDefaultsRecentSearchRepositoryTests {
    @Test func savesAndLoads() async throws {
        let suiteName = "test.recent.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UserDefaultsRecentSearchRepository(defaults: defaults)

        #expect(await repository.load().isEmpty)
        await repository.save(["카페", "편의점"])

        #expect(await repository.load() == ["카페", "편의점"])
    }
}
