import Testing
@testable import MapPilot

struct GeoMathTests {
    @Test func samePointIsZero() {
        #expect(GeoMath.distanceMeters(Fixtures.cityHall, Fixtures.cityHall) == 0)
    }

    @Test func cityHallToGangnamIsAbout8_9km() {
        let distance = GeoMath.distanceMeters(Fixtures.cityHall, Fixtures.gangnamStation)
        #expect(abs(distance - 8_900) < 300)
    }

    @Test func isSymmetric() {
        let ab = GeoMath.distanceMeters(Fixtures.cityHall, Fixtures.gangnamStation)
        let ba = GeoMath.distanceMeters(Fixtures.gangnamStation, Fixtures.cityHall)
        #expect(ab == ba)
    }

    @Test func antipodalPointsDoNotProduceNaN() {
        let a = GeoPoint(latitude: 0, longitude: 0)
        let b = GeoPoint(latitude: 0, longitude: 180)
        let distance = GeoMath.distanceMeters(a, b)
        #expect(!distance.isNaN)
        #expect(abs(distance - .pi * GeoMath.earthRadiusMeters) < 1)
    }
}
