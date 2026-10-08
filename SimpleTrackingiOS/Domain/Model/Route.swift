import Foundation

struct Route: Equatable, Sendable {
    /// 출발지 → 도로 좌표들 → 도착지.
    let points: [GeoPoint]
    let distanceMeters: Int
    let durationSeconds: Int
    /// 자동차 경로의 예상 택시비(원). 도보 등에는 없다.
    var taxiFare: Int? = nil
    /// 자동차 경로의 통행료(원).
    var tollFare: Int? = nil
}
