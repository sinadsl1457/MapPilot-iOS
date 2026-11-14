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

    /// 정지 중 + 따라가기 꺼짐 + 나침반 방향을 알 때. 점 위에 작은 화살촉이 붙어 폰이 향한 방향을 가리킨다.
    /// 36pt: 화살촉이 후광 밖으로 나오도록 점보다 크게 잡는다. 회전은 POI가 맡는다.
    static func headingDot() -> UIImage {
        let size = CGSize(width: 36, height: 36)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let center = CGPoint(x: 18, y: 18)
            tint.withAlphaComponent(0.2).setFill()
            circle(center: center, radius: 14).fill()

            let pointer = UIBezierPath()
            pointer.move(to: CGPoint(x: 18, y: 1.5))
            pointer.addLine(to: CGPoint(x: 23.5, y: 9.5))
            pointer.addLine(to: CGPoint(x: 12.5, y: 9.5))
            pointer.close()
            pointer.lineJoinStyle = .round
            pointer.lineWidth = 1.5
            tint.setFill()
            pointer.fill()
            UIColor.white.setStroke()
            pointer.stroke()

            UIColor.white.setFill()
            circle(center: center, radius: 8).fill()
            tint.setFill()
            circle(center: center, radius: 6).fill()
        }
    }

    /// 따라가기 중 정지해 있을 때 점 아래에 까는 방향 콘(부채꼴). 80pt, 위(북쪽)를 향하고 바깥으로 갈수록 투명하다.
    static func headingCone() -> UIImage {
        let size = CGSize(width: 80, height: 80)
        let center = CGPoint(x: 40, y: 40)
        return UIGraphicsImageRenderer(size: size).image { context in
            // UIKit 각도는 오른쪽이 0이고 시계방향이다. 위쪽(-π/2)을 가운데로 양옆 35°씩.
            let half = coneSpread / 2
            let wedge = UIBezierPath()
            wedge.move(to: center)
            wedge.addArc(withCenter: center, radius: 40, startAngle: -.pi / 2 - half, endAngle: -.pi / 2 + half, clockwise: true)
            wedge.close()
            wedge.addClip()

            let colors = [tint.withAlphaComponent(0.5).cgColor, tint.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 1]) else { return }
            context.cgContext.drawRadialGradient(
                gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: 40, options: []
            )
        }
    }

    private static let coneSpread: CGFloat = 70 * .pi / 180

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
