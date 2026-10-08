import Foundation

struct UserLocation: Equatable, Sendable {
    let point: GeoPoint
    /// 북쪽 기준 시계방향 각도(도). 정지 중이거나 알 수 없으면 nil.
    let bearing: Double?
    let accuracyMeters: Double
    let timestamp: Date
}
