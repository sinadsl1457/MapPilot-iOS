import Foundation

/// 검색어 정리 규칙: 앞뒤 공백을 지우고 연속된 공백을 하나로 줄인다.
/// 검색·최근 검색어·실시간 검색이 같은 규칙을 써야 "카페 "와 "카페"를 같은 검색어로 본다.
enum QueryNormalizer {
    static func normalize(_ query: String) -> String {
        query.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
