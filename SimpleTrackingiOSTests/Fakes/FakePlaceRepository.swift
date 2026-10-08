import Foundation
@testable import SimpleTrackingiOS

actor FakePlaceRepository: PlaceRepository {
    private(set) var receivedQueries: [String] = []
    private let result: [Place]

    init(result: [Place] = []) {
        self.result = result
    }

    func searchPlaces(query: String, center: GeoPoint?) async throws -> [Place] {
        receivedQueries.append(query)
        return result
    }
}
