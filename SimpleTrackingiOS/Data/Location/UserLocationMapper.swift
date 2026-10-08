import CoreLocation

enum UserLocationMapper {
    /// 이보다 느리면 course가 무작위로 튀므로 방향을 쓰지 않는다(m/s).
    static let minimumSpeedForBearing = 0.5

    static func map(_ location: CLLocation) -> UserLocation {
        let hasReliableCourse = location.course >= 0 && location.speed >= minimumSpeedForBearing
        return UserLocation(
            point: GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            bearing: hasReliableCourse ? location.course : nil,
            accuracyMeters: location.horizontalAccuracy < 0 ? .greatestFiniteMagnitude : location.horizontalAccuracy,
            timestamp: location.timestamp
        )
    }
}
