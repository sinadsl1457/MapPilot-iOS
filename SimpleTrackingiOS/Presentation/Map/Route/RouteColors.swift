import SwiftUI
import UIKit

/// 길찾기 화면과 지도 경로 선이 같은 색을 쓰도록 한 곳에 모은다.
enum RouteLineColors {
    static let car = UIColor(red: 0x35 / 255, green: 0x6D / 255, blue: 0xF3 / 255, alpha: 1)
    static let walk = UIColor(red: 0x8E / 255, green: 0x94 / 255, blue: 0x9B / 255, alpha: 1)
    static let bus = UIColor(red: 0x1F / 255, green: 0xA4 / 255, blue: 0x63 / 255, alpha: 1)
    static let subway = UIColor(red: 0x6A / 255, green: 0x5A / 255, blue: 0xE0 / 255, alpha: 1)
    static let end = UIColor(red: 0xF2 / 255, green: 0x46 / 255, blue: 0x4B / 255, alpha: 1)
}

enum RouteColors {
    static let start = Color(uiColor: RouteLineColors.car)
    static let end = Color(uiColor: RouteLineColors.end)

    /// 구간 색. 지하철은 노선 색, 모르는 노선이면 종류 기본색. 지도 경로선과 같은 색이다.
    static func leg(_ leg: TransitLeg) -> Color {
        SubwayLineColors.rgb(of: leg).map { Color(uiColor: UIColor(rgb: $0)) } ?? Self.leg(leg.kind)
    }

    static func leg(_ kind: TransitLeg.Kind) -> Color {
        switch kind {
        case .walk: Color(uiColor: RouteLineColors.walk)
        case .bus: Color(uiColor: RouteLineColors.bus)
        case .subway: Color(uiColor: RouteLineColors.subway)
        }
    }
}

extension UIColor {
    /// 0xRRGGBB → 불투명 색
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension TravelMode {
    var title: String {
        switch self {
        case .transit: String(localized: "travelMode.transit")
        case .car: String(localized: "travelMode.car")
        case .walk: String(localized: "travelMode.walk")
        }
    }

    var symbolName: String {
        switch self {
        case .transit: "bus.fill"
        case .car: "car.fill"
        case .walk: "figure.walk"
        }
    }
}

extension TransitLeg.Kind {
    var symbolName: String {
        switch self {
        case .walk: "figure.walk"
        case .bus: "bus.fill"
        case .subway: "tram.fill"
        }
    }
}
