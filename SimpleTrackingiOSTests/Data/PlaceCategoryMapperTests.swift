import Testing
@testable import SimpleTrackingiOS

struct PlaceCategoryMapperTests {
    @Test(arguments: [
        (PlaceCategory.restaurant, "FD6"),
        (.cafe, "CE7"),
        (.convenienceStore, "CS2"),
        (.gasStation, "OL7"),
        (.pharmacy, "PM9"),
        (.parking, "PK6"),
    ])
    func mapsToKakaoCode(category: PlaceCategory, code: String) {
        #expect(PlaceCategoryMapper.kakaoCode(category) == code)
    }
}
