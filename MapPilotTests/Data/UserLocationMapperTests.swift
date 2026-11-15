import CoreLocation
import Testing
@testable import MapPilot

struct UserLocationMapperTests {
    @Test(arguments: [
        (90.0, 0.5, 90.0 as Double?),   // 기준 속도 이상이면 course 사용
        (90.0, 10.0, 90.0),
        (90.0, 0.49, nil),              // 너무 느리면 방향이 튐
        (-1.0, 10.0, nil),              // course 무효
        (90.0, -1.0, nil),              // speed 무효
    ])
    func bearingRequiresValidCourseAndSpeed(course: Double, speed: Double, expected: Double?) {
        let mapped = UserLocationMapper.map(location(course: course, speed: speed))
        #expect(mapped.bearing == expected)
    }

    @Test func invalidHorizontalAccuracyBecomesInfinitelyBad() {
        let mapped = UserLocationMapper.map(location(horizontalAccuracy: -1))
        #expect(mapped.accuracyMeters == .greatestFiniteMagnitude)
    }

    @Test func mapsCoordinateAccuracyAndTimestamp() {
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let mapped = UserLocationMapper.map(location(horizontalAccuracy: 12, timestamp: timestamp))

        #expect(mapped.point == Fixtures.cityHall)
        #expect(mapped.accuracyMeters == 12)
        #expect(mapped.timestamp == timestamp)
    }

    private func location(
        horizontalAccuracy: Double = 5,
        course: Double = -1,
        speed: Double = -1,
        timestamp: Date = Date(timeIntervalSince1970: 0)
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: Fixtures.cityHall.latitude, longitude: Fixtures.cityHall.longitude),
            altitude: 0,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: 5,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }
}
