import Foundation

enum PlaceMapper {
    /// 좌표를 숫자로 바꿀 수 없으면 nil.
    static func map(_ dto: PlaceDocumentDTO) -> Place? {
        guard let longitude = Double(dto.x), let latitude = Double(dto.y) else { return nil }
        return Place(
            id: dto.id,
            name: dto.placeName,
            category: lastCategory(dto.categoryName),
            address: dto.roadAddressName.isEmpty ? dto.addressName : dto.roadAddressName,
            phone: dto.phone,
            location: GeoPoint(latitude: latitude, longitude: longitude),
            distanceMeters: dto.distance.flatMap { Int($0) }
        )
    }

    /// "음식점 > 카페 > 커피전문점" → "커피전문점"
    private static func lastCategory(_ categoryName: String) -> String {
        categoryName.components(separatedBy: " > ").last ?? categoryName
    }
}
