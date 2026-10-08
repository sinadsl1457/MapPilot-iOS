import Foundation

protocol PlaceRepository: Sendable {
    /// - Parameter center: 거리 계산 기준 좌표. nil이면 결과의 `distanceMeters`도 nil이다.
    func searchPlaces(query: String, center: GeoPoint?) async throws -> [Place]
}
