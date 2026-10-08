@preconcurrency import KakaoMapsSDK
import UIKit

/// Kakao Maps SDK의 명령형 API를 모으는 곳. 엔진 수명주기, 카메라, 내 위치 마커를 맡는다.
/// SDK 타입은 이 폴더 밖으로 나가지 않는다.
@MainActor
final class KakaoMapController: NSObject {
    static let defaultCenter = GeoPoint(latitude: 37.5666, longitude: 126.9784) // 서울시청
    static let defaultZoom = 15

    private enum ID {
        static let mapView = "mapview"
        static let myLocationLayer = "myLocation"
        static let myLocationPoi = "myLocation.poi"
        static let dotStyle = "myLocation.dot"
        static let arrowStyle = "myLocation.arrow"
        static let placeLayer = "places"
        static let routeLayer = "route"
        static func routeStyle(_ kind: RouteLine.Kind) -> String { "route.style.\(kind)" }
        static let routeEndpointLayer = "route.endpoints"
        static let routeStartPoi = "route.start"
        static let routeEndPoi = "route.end"
        static let routeStartStyle = "route.start.style"
        static let routeEndStyle = "route.end.style"
        static func placeStyle(number: Int, selected: Bool) -> String {
            "place.\(number)\(selected ? ".selected" : "")"
        }
    }

    private static let markerAnimationMillis: UInt = 800
    private static let cameraAnimationMillis: UInt = 300
    private static var isSDKInitialized = false

    private let state: KakaoMapState
    private var controller: KMController?
    private weak var container: KMViewContainer?
    private var shouldBeActive = false

    private var map: KakaoMap? { controller?.getView(ID.mapView) as? KakaoMap }
    private var myLocationPoi: Poi?
    private var myLocationStyle: String?
    private var registeredPlaceStyles: Set<String> = []
    private var shownPlaceMarkers: [PlaceMarker] = []
    private var shownSelectedPlaceID: String?
    private var placeTapHandlers: [any DisposableEventHandler] = []
    private var cameraStoppedHandler: (any DisposableEventHandler)?
    private var routeDrawCount = 0

    /// 마지막으로 적용한 회전값. 359° → 1°처럼 경계를 넘을 때 반대로 한 바퀴 돌지 않게 이어 붙인다.
    private var lastRoll: Double?

    init(appKey: String, state: KakaoMapState) {
        self.state = state
        super.init()
        if !Self.isSDKInitialized {
            SDKInitializer.InitSDK(appKey: appKey)
            Self.isSDKInitialized = true
        }
    }

    // MARK: - 엔진 수명주기 (KakaoMapView가 호출)

    func makeContainer() -> KMViewContainer {
        // SDK는 크기가 0인 컨테이너에서 뷰를 만들지 못하므로 임시 크기를 준다. 실제 크기는 레이아웃 후 containerDidResized로 들어온다.
        let container = KMViewContainer(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        // SDK는 제스처 인식기 대신 터치를 직접 받는다. UIView 기본값(false)이면 두 번째 손가락이 전달되지 않아 핀치 줌·회전이 안 된다.
        container.isMultipleTouchEnabled = true
        let controller = KMController(viewContainer: container)
        controller.delegate = self
        self.container = container
        self.controller = controller
        _ = controller.prepareEngine()
        return container
    }

    /// 엔진은 앱이 active일 때만 활성 상태여야 한다.
    func setActive(_ active: Bool) {
        shouldBeActive = active
        guard let controller else { return }
        if active {
            if !controller.isEnginePrepared { _ = controller.prepareEngine() }
            if !controller.isEngineActive { controller.activateEngine() }
        } else if controller.isEngineActive {
            controller.pauseEngine()
        }
    }

    func tearDown() {
        state.detach()
        disposePlaceTapHandlers()
        cameraStoppedHandler?.dispose()
        cameraStoppedHandler = nil
        myLocationPoi = nil
        controller?.pauseEngine()
        controller?.resetEngine()
        controller = nil
    }

    // MARK: - 지도 준비

    private func configureMyLocationLayer(on map: KakaoMap) {
        let labelManager = map.getLabelManager()
        let layerOptions = LabelLayerOptions(
            layerID: ID.myLocationLayer,
            competitionType: .none,
            competitionUnit: .symbolFirst,
            orderType: .rank,
            zOrder: 10_000
        )
        _ = labelManager.addLabelLayer(option: layerOptions)
        labelManager.addPoiStyle(PoiStyle(styleID: ID.dotStyle, styles: [
            PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: MyLocationMarkerImages.dot()), level: 0),
        ]))
        labelManager.addPoiStyle(PoiStyle(styleID: ID.arrowStyle, styles: [
            PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: MyLocationMarkerImages.arrow()), level: 0),
        ]))
    }

    private func configurePlaceLayer(on map: KakaoMap) {
        // 결과끼리 겹쳐도 모두 보이도록 경쟁하지 않는다. 내 위치 레이어보다 아래에 그린다.
        _ = map.getLabelManager().addLabelLayer(option: LabelLayerOptions(
            layerID: ID.placeLayer,
            competitionType: .none,
            competitionUnit: .symbolFirst,
            orderType: .rank,
            zOrder: 9_000
        ))
    }

    private func configureRouteLayers(on map: KakaoMap) {
        let routeManager = map.getRouteManager()
        _ = routeManager.addRouteLayer(layerID: ID.routeLayer, zOrder: 8_000)
        // 종류마다 스타일 세트를 따로 두고, 구간 하나를 경로 하나로 그린다.
        let styles: [(RouteLine.Kind, UIColor, UInt)] = [
            (.car, RouteLineColors.car, 8),
            (.walk, RouteLineColors.walk, 5),
            (.bus, RouteLineColors.bus, 8),
            (.subway, RouteLineColors.subway, 8),
        ]
        for (kind, color, width) in styles {
            routeManager.addRouteStyleSet(RouteStyleSet(styleID: ID.routeStyle(kind), styles: [
                RouteStyle(styles: [PerLevelRouteStyle(width: width, color: color, strokeWidth: 2, strokeColor: .white, level: 0)]),
            ]))
        }

        let labelManager = map.getLabelManager()
        _ = labelManager.addLabelLayer(option: LabelLayerOptions(
            layerID: ID.routeEndpointLayer,
            competitionType: .none,
            competitionUnit: .symbolFirst,
            orderType: .rank,
            zOrder: 9_500
        ))
        labelManager.addPoiStyle(PoiStyle(styleID: ID.routeStartStyle, styles: [
            PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: RouteMarkerImages.start(), anchorPoint: CGPoint(x: 0.5, y: 1)), level: 0),
        ]))
        labelManager.addPoiStyle(PoiStyle(styleID: ID.routeEndStyle, styles: [
            PerLevelPoiStyle(iconStyle: PoiIconStyle(symbol: RouteMarkerImages.end(), anchorPoint: CGPoint(x: 0.5, y: 1)), level: 0),
        ]))
    }

    private func observeCamera(on map: KakaoMap) {
        cameraStoppedHandler = map.addCameraStoppedEventHandler(target: self) { controller in
            { _ in controller.reportCameraCenter() }
        }
        reportCameraCenter()
    }

    private func reportCameraCenter() {
        guard let map else { return }
        let rect = map.viewRect
        let coordinate = map.getPosition(CGPoint(x: rect.midX, y: rect.midY)).wgsCoord
        state.cameraDidStop(at: GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    private func placeStyleID(number: Int, selected: Bool, labelManager: LabelManager) -> String {
        let id = ID.placeStyle(number: number, selected: selected)
        if !registeredPlaceStyles.contains(id) {
            let icon = PoiIconStyle(symbol: PlaceMarkerImages.pin(number: number, selected: selected), anchorPoint: CGPoint(x: 0.5, y: 1))
            labelManager.addPoiStyle(PoiStyle(styleID: id, styles: [PerLevelPoiStyle(iconStyle: icon, level: 0)]))
            registeredPlaceStyles.insert(id)
        }
        return id
    }

    private func disposePlaceTapHandlers() {
        placeTapHandlers.forEach { $0.dispose() }
        placeTapHandlers.removeAll()
    }

    /// 선택된 마커가 다른 마커에 가려지지 않게 rank를 가장 높게 준다. 번호가 작을수록 위에 그린다.
    private static func placeRank(number: Int, selected: Bool) -> Int {
        selected ? 1_000 : 1_000 - number
    }

    private static func mapPoint(_ point: GeoPoint) -> MapPoint {
        MapPoint(longitude: point.longitude, latitude: point.latitude)
    }

    /// bearing(도, 북쪽 기준 시계방향) → POI roll(라디안).
    /// SDK 문서에 단위·방향이 적혀 있지 않아 실제 화면에서 확인해야 한다.
    private static func roll(fromBearing bearing: Double) -> Double {
        bearing * .pi / 180
    }

    private func continuousRoll(toward target: Double) -> Double {
        guard let lastRoll else { return target }
        var delta = (target - lastRoll).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return lastRoll + delta
    }
}

// MARK: - KakaoMapCommands

extension KakaoMapController: KakaoMapCommands {
    func moveCamera(to point: GeoPoint, zoom: Int) {
        guard let map else { return }
        map.animateCamera(
            cameraUpdate: CameraUpdate.make(target: Self.mapPoint(point), zoomLevel: zoom, mapView: map),
            options: CameraAnimationOptions(autoElevation: false, consecutive: false, durationInMillis: Self.cameraAnimationMillis)
        )
    }

    /// 지점이 모두 보이게 맞춘다. 위·아래 UI가 지도를 가리는 만큼 영역을 넓혀 잡는다.
    func fitCamera(to points: [GeoPoint], layout: MapFitLayout) {
        guard let map else { return }
        if points.count == 1, let point = points.first {
            moveCamera(to: point, zoom: 16)
            return
        }
        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else { return }
        let latSpan = max(maxLat - minLat, 0.002)
        let lonSpan = max(maxLon - minLon, 0.002)
        // 위도 범위 대비 위·아래로 더 잡을 비율
        let (top, bottom): (Double, Double) = switch layout {
        case .searchResults: (0.5, 1.2)
        case .route: (0.8, 0.5)
        case .routeWithSheet: (0.9, 1.3)
        }
        let area = AreaRect(
            southWest: MapPoint(longitude: minLon - lonSpan * 0.1, latitude: minLat - latSpan * bottom),
            northEast: MapPoint(longitude: maxLon + lonSpan * 0.1, latitude: maxLat + latSpan * top)
        )
        map.animateCamera(
            cameraUpdate: CameraUpdate.make(area: area, levelLimit: 17),
            options: CameraAnimationOptions(autoElevation: false, consecutive: false, durationInMillis: Self.cameraAnimationMillis)
        )
    }

    func showPlaceMarkers(_ markers: [PlaceMarker], selectedID: String?) {
        guard let map, let layer = map.getLabelManager().getLabelLayer(layerID: ID.placeLayer) else { return }
        let labelManager = map.getLabelManager()

        // 같은 결과에서 선택만 바뀌었으면 스타일만 바꾼다.
        if markers == shownPlaceMarkers {
            for marker in markers where marker.id == shownSelectedPlaceID || marker.id == selectedID {
                guard let poi = layer.getPoi(poiID: marker.id) else { continue }
                let selected = marker.id == selectedID
                poi.changeStyle(styleID: placeStyleID(number: marker.number, selected: selected, labelManager: labelManager))
                poi.rank = Self.placeRank(number: marker.number, selected: selected)
            }
            shownSelectedPlaceID = selectedID
            return
        }

        disposePlaceTapHandlers()
        layer.clearAllItems()
        for marker in markers {
            let selected = marker.id == selectedID
            let options = PoiOptions(styleID: placeStyleID(number: marker.number, selected: selected, labelManager: labelManager), poiID: marker.id)
            options.rank = Self.placeRank(number: marker.number, selected: selected)
            options.clickable = true
            guard let poi = layer.addPoi(option: options, at: Self.mapPoint(marker.point)) else { continue }
            placeTapHandlers.append(poi.addPoiTappedEventHandler(target: self) { controller in
                { param in controller.state.placeMarkerTapped(id: param.poiItem.itemID) }
            })
            poi.show()
        }
        shownPlaceMarkers = markers
        shownSelectedPlaceID = selectedID
    }

    func showRoute(_ overlay: RouteOverlay?) {
        guard let map,
              let routeLayer = map.getRouteManager().getRouteLayer(layerID: ID.routeLayer),
              let endpointLayer = map.getLabelManager().getLabelLayer(layerID: ID.routeEndpointLayer)
        else { return }

        routeLayer.clearAllRoutes()
        endpointLayer.clearAllItems()
        guard let overlay else { return }

        // 지우기가 비동기라 같은 ID를 바로 다시 쓰면 충돌할 수 있어 그릴 때마다 새 ID를 쓴다.
        routeDrawCount += 1
        for (index, line) in overlay.lines.enumerated() where line.points.count >= 2 {
            let options = RouteOptions(routeID: "route.\(routeDrawCount).\(index)", styleID: ID.routeStyle(line.kind), zOrder: index)
            options.segments = [RouteSegment(points: line.points.map(Self.mapPoint), styleIndex: 0)]
            routeLayer.addRoute(option: options)?.show()
        }

        for (poiID, styleID, point) in [(ID.routeStartPoi, ID.routeStartStyle, overlay.start), (ID.routeEndPoi, ID.routeEndStyle, overlay.end)] {
            let poiOptions = PoiOptions(styleID: styleID, poiID: poiID)
            poiOptions.rank = 1
            endpointLayer.addPoi(option: poiOptions, at: Self.mapPoint(point))?.show()
        }
    }

    func updateMyLocation(_ location: UserLocation?) {
        guard let layer = map?.getLabelManager().getLabelLayer(layerID: ID.myLocationLayer) else { return }

        guard let location else {
            layer.removePoi(poiID: ID.myLocationPoi)
            myLocationPoi = nil
            myLocationStyle = nil
            lastRoll = nil
            return
        }

        let point = Self.mapPoint(location.point)
        let style = location.bearing == nil ? ID.dotStyle : ID.arrowStyle

        if let poi = myLocationPoi {
            if style != myLocationStyle {
                poi.changeStyle(styleID: style)
                myLocationStyle = style
            }
            poi.moveAt(point, duration: Self.markerAnimationMillis)
            if let bearing = location.bearing {
                let roll = continuousRoll(toward: Self.roll(fromBearing: bearing))
                poi.rotateAt(roll, duration: Self.markerAnimationMillis)
                lastRoll = roll
            }
        } else {
            let options = PoiOptions(styleID: style, poiID: ID.myLocationPoi)
            options.rank = Int(Int32.max)
            options.clickable = false
            // 지도를 돌려도 실제 방위를 가리키도록 절대 회전을 쓴다.
            options.transformType = .absoluteRotation
            guard let poi = layer.addPoi(option: options, at: point) else { return }
            if let bearing = location.bearing {
                let roll = Self.roll(fromBearing: bearing)
                poi.rotateAt(roll, duration: 0)
                lastRoll = roll
            }
            poi.show()
            myLocationPoi = poi
            myLocationStyle = style
        }
    }
}

// MARK: - MapControllerDelegate

extension KakaoMapController: @preconcurrency MapControllerDelegate {
    func addViews() {
        let info = MapviewInfo(
            viewName: ID.mapView,
            viewInfoName: "map",
            defaultPosition: Self.mapPoint(Self.defaultCenter),
            defaultLevel: Self.defaultZoom
        )
        controller?.addView(info)
    }

    func addViewSucceeded(_ viewName: String, viewInfoName: String) {
        guard let map else { return }
        if let container {
            map.viewRect = container.bounds
        }
        configurePlaceLayer(on: map)
        configureRouteLayers(on: map)
        configureMyLocationLayer(on: map)
        observeCamera(on: map)
        state.attach(self)
    }

    func addViewFailed(_ viewName: String, viewInfoName: String) {
        state.fail("addView(\(viewName)) failed")
    }

    func containerDidResized(_ size: CGSize) {
        map?.viewRect = CGRect(origin: .zero, size: size)
    }

    func authenticationFailed(_ errorCode: Int, desc: String) {
        state.fail("\(desc) (\(errorCode))")
    }
}
