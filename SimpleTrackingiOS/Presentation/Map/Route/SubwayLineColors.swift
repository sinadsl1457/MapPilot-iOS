import Foundation

/// 수도권 전철 노선 공식 색(0xRRGGBB). 목록(TransitRouteList)과 지도 경로선(RouteViewModel.overlay)이 같이 쓴다.
enum SubwayLineColors {
    /// 지하철 구간의 노선 색. 지하철이 아니거나 모르는 노선이면 nil → 기본 지하철 색을 쓴다.
    static func rgb(of leg: TransitLeg) -> UInt32? {
        guard leg.kind == .subway else { return nil }
        return leg.lineNames.lazy.compactMap(rgb(lineName:)).first
    }

    /// 카카오 응답의 노선 이름(예: "2호선", "수인분당선")으로 찾는다.
    static func rgb(lineName: String) -> UInt32? {
        let name = lineName.replacingOccurrences(of: " ", with: "")
        // "인천1호선"이 "1호선"에 걸리지 않도록 이름 있는 노선부터 본다.
        if let named = namedLines.first(where: { name.contains($0.key) }) {
            return named.rgb
        }
        guard let match = name.firstMatch(of: /^(?:수도권|서울)?([1-9])호선/), let number = Int(match.1) else { return nil }
        return numberedLines[number]
    }

    private static let numberedLines: [Int: UInt32] = [
        1: 0x0052A4, 2: 0x00A84D, 3: 0xEF7C1C, 4: 0x00A5DE, 5: 0x996CAC,
        6: 0xCD7C2F, 7: 0x747F00, 8: 0xE6186C, 9: 0xBDB092,
    ]

    private static let namedLines: [(key: String, rgb: UInt32)] = [
        ("인천1호선", 0x7CA8D5),
        ("인천2호선", 0xED8B00),
        ("수인분당", 0xF5A200),
        ("신분당", 0xD4003B),
        ("경의중앙", 0x77C4A3),
        ("공항철도", 0x0090D2),
        ("경춘", 0x0C8E72),
        ("경강", 0x0054A6),
        ("서해", 0x81A914),
        ("우이신설", 0xB0CE18),
        ("신림", 0x6789CA),
        ("김포골드", 0xA17800),
        ("에버라인", 0x6FB245),
        ("용인경전철", 0x6FB245),
        ("의정부", 0xFDA600),
        ("GTX-A", 0x9A6292),
    ]
}
