import UIKit

/// 내 위치 마커 이미지. 에셋 대신 코드로 그린다.
enum MyLocationMarkerImages {
    private static let tint = UIColor(red: 0x35 / 255, green: 0x6D / 255, blue: 0xF3 / 255, alpha: 1)

    /// 정지 중이거나 방향을 모를 때. 28pt: 후광(r14, 20%) → 흰 원(r8) → 파란 원(r6)
    static func dot() -> UIImage {
        let size = CGSize(width: 28, height: 28)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let center = CGPoint(x: 14, y: 14)
            tint.withAlphaComponent(0.2).setFill()
            circle(center: center, radius: 14).fill()
            UIColor.white.setFill()
            circle(center: center, radius: 8).fill()
            tint.setFill()
            circle(center: center, radius: 6).fill()
        }
    }

    /// 이동 중일 때. 32pt, 위(북쪽)를 가리키는 화살표. 회전은 POI가 맡는다.
    static func arrow() -> UIImage {
        let size = CGSize(width: 32, height: 32)
        return UIGraphicsImageRenderer(size: size).image { _ in
            tint.withAlphaComponent(0.2).setFill()
            circle(center: CGPoint(x: 16, y: 16), radius: 16).fill()

            let path = UIBezierPath()
            path.move(to: CGPoint(x: 16, y: 5))
            path.addLine(to: CGPoint(x: 24, y: 26))
            path.addLine(to: CGPoint(x: 16, y: 21.5))
            path.addLine(to: CGPoint(x: 8, y: 26))
            path.close()
            path.lineJoinStyle = .round
            path.lineWidth = 2
            tint.setFill()
            path.fill()
            UIColor.white.setStroke()
            path.stroke()
        }
    }

    private static func circle(center: CGPoint, radius: CGFloat) -> UIBezierPath {
        UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
    }
}
