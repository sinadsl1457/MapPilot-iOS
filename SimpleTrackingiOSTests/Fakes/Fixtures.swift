import Foundation
@testable import SimpleTrackingiOS

enum Fixtures {
    static let cityHall = GeoPoint(latitude: 37.5666, longitude: 126.9784)
    static let gangnamStation = GeoPoint(latitude: 37.49794, longitude: 127.02764)

    static func place(id: String, latitude: Double = 37.5, longitude: Double = 127.0) -> Place {
        Place(
            id: id,
            name: "장소 \(id)",
            category: "카페",
            address: "주소 \(id)",
            phone: "",
            location: GeoPoint(latitude: latitude, longitude: longitude),
            distanceMeters: nil
        )
    }

    static func location(
        latitude: Double = 37.5666,
        longitude: Double = 126.9784,
        bearing: Double? = nil,
        accuracy: Double = 5
    ) -> UserLocation {
        UserLocation(
            point: GeoPoint(latitude: latitude, longitude: longitude),
            bearing: bearing,
            accuracyMeters: accuracy,
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }
}
