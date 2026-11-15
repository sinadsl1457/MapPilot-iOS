import Testing
@testable import MapPilot

struct PlaceMapperTests {
    @Test func mapsAllFields() throws {
        let place = try #require(PlaceMapper.map(.stub()))

        #expect(place == Place(
            id: "1",
            name: "서울시청",
            category: "시청",
            address: "서울 중구 세종대로 110",
            phone: "02-120",
            location: GeoPoint(latitude: 37.5666, longitude: 126.9784),
            distanceMeters: 120
        ))
    }

    @Test(arguments: [("abc", "37.5"), ("126.9", ""), ("", "")])
    func dropsBrokenCoordinates(x: String, y: String) {
        #expect(PlaceMapper.map(.stub(x: x, y: y)) == nil)
    }

    @Test(arguments: [
        ("음식점 > 카페 > 커피전문점", "커피전문점"),
        ("공공기관", "공공기관"),
        ("", ""),
    ])
    func usesLastCategoryToken(categoryName: String, expected: String) throws {
        let place = try #require(PlaceMapper.map(.stub(categoryName: categoryName)))
        #expect(place.category == expected)
    }

    @Test func fallsBackToJibunAddressWhenRoadAddressIsEmpty() throws {
        let place = try #require(PlaceMapper.map(.stub(addressName: "서울 중구 태평로1가 31", roadAddressName: "")))
        #expect(place.address == "서울 중구 태평로1가 31")
    }

    @Test(arguments: [("", nil), ("abc", nil), (nil, nil), ("0", 0), ("1532", 1532)] as [(String?, Int?)])
    func parsesDistance(distance: String?, expected: Int?) throws {
        let place = try #require(PlaceMapper.map(.stub(distance: distance)))
        #expect(place.distanceMeters == expected)
    }
}

extension PlaceDocumentDTO {
    static func stub(
        categoryName: String = "공공,사회기관 > 행정기관 > 시청",
        addressName: String = "서울 중구 태평로1가 31",
        roadAddressName: String = "서울 중구 세종대로 110",
        x: String = "126.9784",
        y: String = "37.5666",
        distance: String? = "120"
    ) -> PlaceDocumentDTO {
        PlaceDocumentDTO(
            id: "1",
            placeName: "서울시청",
            categoryName: categoryName,
            addressName: addressName,
            roadAddressName: roadAddressName,
            phone: "02-120",
            x: x,
            y: y,
            distance: distance
        )
    }
}
