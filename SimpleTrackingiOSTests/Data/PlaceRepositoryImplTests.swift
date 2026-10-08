import Testing
@testable import SimpleTrackingiOS

struct PlaceRepositoryImplTests {
    @Test func decodesAndMapsDocumentsSkippingBrokenOnes() async throws {
        let json = """
        {
          "meta": {"total_count": 2},
          "documents": [
            {
              "id": "8", "place_name": "서울시청", "category_name": "공공,사회기관 > 행정기관 > 시청",
              "address_name": "서울 중구 태평로1가 31", "road_address_name": "서울 중구 세종대로 110",
              "phone": "02-120", "x": "126.9784", "y": "37.5666", "distance": "", "place_url": "http://place.map.kakao.com/8"
            },
            {
              "id": "9", "place_name": "좌표 없음", "category_name": "", "address_name": "", "road_address_name": "",
              "phone": "", "x": "", "y": "", "distance": ""
            }
          ]
        }
        """
        let client = KakaoAPIClient(restAPIKey: "k", session: StubURLProtocol.makeSession(status: 200, json: json))

        let places = try await PlaceRepositoryImpl(client: client).searchPlaces(query: "시청", center: nil)

        #expect(places == [Place(
            id: "8",
            name: "서울시청",
            category: "시청",
            address: "서울 중구 세종대로 110",
            phone: "02-120",
            location: GeoPoint(latitude: 37.5666, longitude: 126.9784),
            distanceMeters: nil
        )])
    }
}
