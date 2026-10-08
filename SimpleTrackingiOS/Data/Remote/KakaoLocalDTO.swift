import Foundation

/// `GET /v2/local/search/keyword.json` 응답.
struct KeywordSearchResponseDTO: Decodable, Sendable {
    let documents: [PlaceDocumentDTO]
}

struct PlaceDocumentDTO: Decodable, Sendable {
    let id: String
    let placeName: String
    let categoryName: String
    let addressName: String
    let roadAddressName: String
    let phone: String
    /// 경도. 문자열로 내려온다.
    let x: String
    /// 위도. 문자열로 내려온다.
    let y: String
    /// 기준 좌표 없이 검색하면 빈 문자열이다.
    let distance: String?
}
