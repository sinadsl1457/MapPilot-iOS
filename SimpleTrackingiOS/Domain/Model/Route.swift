import Foundation

struct Route: Equatable, Sendable {
    /// 출발지 → 도로 좌표들 → 도착지.
    let points: [GeoPoint]
    let distanceMeters: Int
    let durationSeconds: Int
}
