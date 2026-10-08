import Foundation

/// Kakao 로컬/모빌리티 REST API 클라이언트.
struct KakaoAPIClient: Sendable {
    static let keywordSearchURL = URL(string: "https://dapi.kakao.com/v2/local/search/keyword.json")!
    static let categorySearchURL = URL(string: "https://dapi.kakao.com/v2/local/search/category.json")!
    static let directionsURL = URL(string: "https://apis-navi.kakaomobility.com/v1/directions")!
    static let walkURL = URL(string: "https://dapi.kakao.com/v2/routing/walk")!
    static let transitURL = URL(string: "https://dapi.kakao.com/v2/routing/publictraffic")!
    static let searchPageSize = 15

    private let restAPIKey: String
    private let session: URLSession

    init(restAPIKey: String, session: URLSession = .shared) {
        self.restAPIKey = restAPIKey
        self.session = session
    }

    func searchKeyword(query: String, center: GeoPoint?) async throws -> KeywordSearchResponseDTO {
        var items = [URLQueryItem(name: "query", value: query)]
        if let center {
            items.append(URLQueryItem(name: "x", value: String(center.longitude)))
            items.append(URLQueryItem(name: "y", value: String(center.latitude)))
        }
        items.append(URLQueryItem(name: "size", value: String(Self.searchPageSize)))
        return try await get(Self.keywordSearchURL, queryItems: items)
    }

    /// 카테고리 검색. 응답 형식은 키워드 검색과 같다.
    func searchCategory(code: String, center: GeoPoint, radiusMeters: Int) async throws -> KeywordSearchResponseDTO {
        try await get(Self.categorySearchURL, queryItems: [
            URLQueryItem(name: "category_group_code", value: code),
            URLQueryItem(name: "x", value: String(center.longitude)),
            URLQueryItem(name: "y", value: String(center.latitude)),
            URLQueryItem(name: "radius", value: String(radiusMeters)),
            URLQueryItem(name: "sort", value: "distance"),
            URLQueryItem(name: "size", value: String(Self.searchPageSize)),
        ])
    }

    func directions(from origin: GeoPoint, to destination: GeoPoint) async throws -> DirectionsResponseDTO {
        try await get(Self.directionsURL, queryItems: [
            URLQueryItem(name: "origin", value: Self.lonLat(origin)),
            URLQueryItem(name: "destination", value: Self.lonLat(destination)),
            // 최단 거리(DISTANCE)는 막히는 길로 돌아 실제로 더 오래 걸릴 수 있어 카카오 기본값인 추천 경로를 쓴다.
            URLQueryItem(name: "priority", value: "RECOMMEND"),
        ])
    }

    func walkingRoute(from origin: GeoPoint, to destination: GeoPoint) async throws -> WalkResponseDTO {
        try await get(Self.walkURL, queryItems: Self.routingItems(origin, destination))
    }

    func transitRoutes(from origin: GeoPoint, to destination: GeoPoint) async throws -> TransitResponseDTO {
        try await get(Self.transitURL, queryItems: Self.routingItems(origin, destination))
    }

    /// 카카오맵 경로 API는 좌표를 x(경도)·y(위도) 파라미터로 따로 받는다.
    private static func routingItems(_ origin: GeoPoint, _ destination: GeoPoint) -> [URLQueryItem] {
        [
            URLQueryItem(name: "start_x", value: String(origin.longitude)),
            URLQueryItem(name: "start_y", value: String(origin.latitude)),
            URLQueryItem(name: "end_x", value: String(destination.longitude)),
            URLQueryItem(name: "end_y", value: String(destination.latitude)),
        ]
    }

    private func get<Response: Decodable>(_ url: URL, queryItems: [URLQueryItem]) async throws -> Response {
        try await safeApiCall {
            var request = URLRequest(url: url.appending(queryItems: queryItems))
            request.setValue("KakaoAK \(restAPIKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard (200..<300).contains(http.statusCode) else { throw HTTPStatusError(statusCode: http.statusCode) }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Response.self, from: data)
        }
    }

    /// 카카오모빌리티는 "경도,위도" 순서를 쓴다.
    private static func lonLat(_ point: GeoPoint) -> String {
        "\(point.longitude),\(point.latitude)"
    }
}
