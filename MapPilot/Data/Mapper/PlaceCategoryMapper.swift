import Foundation

enum PlaceCategoryMapper {
    /// 카카오 로컬 API의 `category_group_code`.
    static func kakaoCode(_ category: PlaceCategory) -> String {
        switch category {
        case .restaurant: "FD6"
        case .cafe: "CE7"
        case .convenienceStore: "CS2"
        case .gasStation: "OL7"
        case .pharmacy: "PM9"
        case .parking: "PK6"
        }
    }
}
