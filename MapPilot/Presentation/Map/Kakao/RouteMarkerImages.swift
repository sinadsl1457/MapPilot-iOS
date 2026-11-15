import UIKit

/// 길찾기 출발·도착 마커. 글자가 들어간 말풍선이 아래 꼭짓점으로 위치를 가리킨다.
enum RouteMarkerImages {
    static func start() -> UIImage {
        bubble(text: String(localized: "route.marker.start"), color: UIColor(red: 0x35 / 255, green: 0x6D / 255, blue: 0xF3 / 255, alpha: 1))
    }

    static func end() -> UIImage {
        bubble(text: String(localized: "route.marker.end"), color: UIColor(red: 0xF2 / 255, green: 0x46 / 255, blue: 0x4B / 255, alpha: 1))
    }

    private static func bubble(text: String, color: UIColor) -> UIImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.white,
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let bodySize = CGSize(width: ceil(textSize.width) + 20, height: 26)
        let tipHeight: CGFloat = 7
        let size = CGSize(width: bodySize.width, height: bodySize.height + tipHeight)

        return UIGraphicsImageRenderer(size: size).image { context in
            let body = UIBezierPath(roundedRect: CGRect(origin: .zero, size: bodySize), cornerRadius: bodySize.height / 2)
            let tip = UIBezierPath()
            tip.move(to: CGPoint(x: size.width / 2 - 6, y: bodySize.height - 1))
            tip.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            tip.addLine(to: CGPoint(x: size.width / 2 + 6, y: bodySize.height - 1))
            tip.close()
            body.append(tip)

            context.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.25).cgColor)
            color.setFill()
            body.fill()
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            (text as NSString).draw(
                at: CGPoint(x: (bodySize.width - textSize.width) / 2, y: (bodySize.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
    }
}
