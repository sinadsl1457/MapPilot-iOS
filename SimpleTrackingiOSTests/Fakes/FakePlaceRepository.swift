import Foundation
@testable import SimpleTrackingiOS

actor FakePlaceRepository: PlaceRepository {
    private(set) var receivedQueries: [String] = []
    private(set) var receivedCategories: [(category: PlaceCategory, center: GeoPoint, radius: Int)] = []
    private let result: [Place]
    private let failure: (any Error)?

    init(result: [Place] = [], failure: (any Error)? = nil) {
        self.result = result
        self.failure = failure
    }

    func searchPlaces(query: String, center: GeoPoint?) async throws -> [Place] {
        receivedQueries.append(query)
        if let failure { throw failure }
        return result
    }

    func searchPlaces(category: PlaceCategory, center: GeoPoint, radiusMeters: Int) async throws -> [Place] {
        receivedCategories.append((category, center, radiusMeters))
        if let failure { throw failure }
        return result
    }
}
