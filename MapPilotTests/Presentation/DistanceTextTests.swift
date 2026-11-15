import Testing
@testable import MapPilot

struct DistanceTextTests {
    @Test(arguments: [
        (0.0, "0m"),
        (320.4, "320m"),
        (999.4, "999m"),
        (1_000.0, "1.0km"),
        (1_234.0, "1.2km"),
        (22_850.0, "22.9km"),
    ])
    func formats(meters: Double, expected: String) {
        #expect(DistanceText.string(meters: meters) == expected)
    }

    @Test func withoutOriginIsNil() {
        #expect(DistanceText.string(from: nil, to: Fixtures.cityHall) == nil)
    }
}
