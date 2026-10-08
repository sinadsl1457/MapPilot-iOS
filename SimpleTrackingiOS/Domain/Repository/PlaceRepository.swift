import Foundation

protocol PlaceRepository: Sendable {
    /// - Parameter center: 거리 계산 기준 좌표. nil이면 결과의 `distanceMeters`도 nil이다.
    func searchPlaces(query: String, center: GeoPoint?) async throws -> [Place]
    /// `center` 반경 `radiusMeters` 안의 장소를 가까운 순으로 찾는다.
    func searchPlaces(category: PlaceCategory, center: GeoPoint, radiusMeters: Int) async throws -> [Place]
}
