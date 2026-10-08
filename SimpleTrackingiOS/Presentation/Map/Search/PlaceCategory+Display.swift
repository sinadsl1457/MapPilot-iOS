import Foundation

extension PlaceCategory {
    var title: String {
        switch self {
        case .restaurant: String(localized: "category.restaurant")
        case .cafe: String(localized: "category.cafe")
        case .convenienceStore: String(localized: "category.convenienceStore")
        case .gasStation: String(localized: "category.gasStation")
        case .pharmacy: String(localized: "category.pharmacy")
        case .parking: String(localized: "category.parking")
        }
    }

    var symbolName: String {
        switch self {
        case .restaurant: "fork.knife"
        case .cafe: "cup.and.saucer.fill"
        case .convenienceStore: "basket.fill"
        case .gasStation: "fuelpump.fill"
        case .pharmacy: "cross.case.fill"
        case .parking: "parkingsign"
        }
    }
}
