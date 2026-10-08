import Foundation

enum DistanceText {
    /// 1km 미만은 m 단위 정수, 이상은 km 소수 첫째 자리. 예: "320m", "1.2km"
    static func string(meters: Double) -> String {
        if meters < 1_000 {
            return "\(Int(meters.rounded()))m"
        }
        // 22850m를 바로 /1000 하면 22.8499…가 되어 22.8로 내려가므로 100m 단위로 먼저 반올림한다.
        let kilometers = (meters / 100).rounded() / 10
        return kilometers.formatted(.number.precision(.fractionLength(1))) + "km"
    }

    /// 내 위치를 알 때만 거리를 보여준다.
    static func string(from origin: GeoPoint?, to destination: GeoPoint) -> String? {
        origin.map { string(meters: GeoMath.distanceMeters($0, destination)) }
    }
}
