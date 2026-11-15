import Foundation
@testable import MapPilot

/// 검색어마다 다른 결과와 응답 지연을 주는 가짜. 실시간 검색에서 "늦게 온 이전 결과"를 만들 때 쓴다.
actor ScriptedPlaceRepository: PlaceRepository {
    private(set) var receivedQueries: [String] = []
    private let results: [String: [Place]]
    private let delays: [String: Duration]

    init(results: [String: [Place]], delays: [String: Duration] = [:]) {
        self.results = results
        self.delays = delays
    }

    func searchPlaces(query: String, center: GeoPoint?) async throws -> [Place] {
        receivedQueries.append(query)
        if let delay = delays[query] {
            // 취소돼도 응답이 늦게 오는 서버처럼 끝까지 기다린다.
            try? await Task.sleep(for: delay)
        }
        return results[query] ?? []
    }

    func searchPlaces(category: PlaceCategory, center: GeoPoint, radiusMeters: Int) async throws -> [Place] {
        []
    }
}
