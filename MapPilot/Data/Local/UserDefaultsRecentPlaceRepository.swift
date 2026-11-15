import Foundation

/// 최근 장소를 기기 안(UserDefaults)에 JSON으로 저장한다. 저장 형식(DTO)은 이 파일만 안다.
struct UserDefaultsRecentPlaceRepository: RecentPlaceRepository {
    static let key = "recentPlaces"

    // UserDefaults는 스레드 안전하지만 Sendable로 표시되어 있지 않다.
    nonisolated(unsafe) private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 저장된 값이 깨졌으면(형식 변경 등) 빈 목록으로 시작한다.
    func load() async -> [RecentPlace] {
        guard let data = defaults.data(forKey: Self.key),
              let dtos = try? JSONDecoder().decode([RecentPlaceDTO].self, from: data) else { return [] }
        return dtos.map(\.domain)
    }

    func save(_ places: [RecentPlace]) async {
        guard let data = try? JSONEncoder().encode(places.map(RecentPlaceDTO.init)) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

/// 저장 형식. 도메인 모델(Place)에 Codable을 붙이지 않으려고 따로 둔다.
private struct RecentPlaceDTO: Codable {
    let id: String
    let name: String
    let category: String
    let address: String
    let phone: String
    let latitude: Double
    let longitude: Double
    let usedAt: Date

    init(_ recent: RecentPlace) {
        let place = recent.place
        id = place.id
        name = place.name
        category = place.category
        address = place.address
        phone = place.phone
        latitude = place.location.latitude
        longitude = place.location.longitude
        usedAt = recent.usedAt
    }

    /// 거리는 저장하지 않는다(고른 때의 내 위치 기준이라 나중에는 맞지 않는다).
    var domain: RecentPlace {
        RecentPlace(
            place: Place(
                id: id, name: name, category: category, address: address, phone: phone,
                location: GeoPoint(latitude: latitude, longitude: longitude),
                distanceMeters: nil
            ),
            usedAt: usedAt
        )
    }
}
