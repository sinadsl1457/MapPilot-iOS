import UIKit

/// 검색 결과 번호 마커. 아래 꼭짓점이 장소 위치를 가리키는 핀 모양이다.
enum PlaceMarkerImages {
    private static let tint = UIColor(red: 0x35 / 255, green: 0x6D / 255, blue: 0xF3 / 255, alpha: 1)

    /// 기본: 흰 바탕, 파란 테두리·번호. 선택: 파란 바탕, 흰 번호, 1.25배.
    static func pin(number: Int, selected: Bool) -> UIImage {
        let scale: CGFloat = selected ? 1.25 : 1
        let width = 28 * scale
        let height = 36 * scale
        let radius = width / 2
        let lineWidth: CGFloat = 2

        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { context in
            let path = UIBezierPath()
            let center = CGPoint(x: radius, y: radius)
            let inset = radius - lineWidth / 2
            // 원의 아래쪽 양옆에서 꼭짓점으로 이어지는 물방울 모양
            path.addArc(withCenter: center, radius: inset, startAngle: .pi * 0.75, endAngle: .pi * 0.25, clockwise: true)
            path.addLine(to: CGPoint(x: radius, y: height - lineWidth))
            path.close()
            path.lineJoinStyle = .round
            path.lineWidth = lineWidth

            context.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.25).cgColor)
            (selected ? tint : .white).setFill()
            path.fill()
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            (selected ? .white : tint).setStroke()
            path.stroke()

            let text = "\(number)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13 * scale, weight: .bold),
                .foregroundColor: selected ? UIColor.white : tint,
            ]
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attributes)
        }
    }
}
