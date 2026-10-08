import Foundation

enum GeoMath {
    static let earthRadiusMeters = 6_371_008.8

    /// 하버사인 공식으로 구한 두 좌표 사이의 거리(m).
    static func distanceMeters(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180

        let sinLat = sin(dLat / 2)
        let sinLon = sin(dLon / 2)
        let h = sinLat * sinLat + cos(lat1) * cos(lat2) * sinLon * sinLon
        // 부동소수점 오차로 1을 살짝 넘으면 asin이 NaN을 낸다.
        let clamped = min(max(h, 0), 1)
        return 2 * earthRadiusMeters * asin(clamped.squareRoot())
    }
}
