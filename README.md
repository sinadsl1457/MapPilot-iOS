# MapPilot (iOS)

카카오맵 SDK로 만든 지도 앱입니다. 내 위치 따라가기, 장소 검색, 자동차·도보·대중교통 길찾기를 네이버 지도와 비슷한 흐름으로 구현했습니다.
같은 기능을 Android 네이티브로도 만들었습니다 → [MapPilot-Android](https://github.com/sinadsl1457/MapPilot-Android)

| 지도·내 위치 | 장소 검색 | 길찾기 |
|---|---|---|
| <!-- docs/screenshots/map.png --> | <!-- docs/screenshots/search.png --> | <!-- docs/screenshots/route.png --> |

## 주요 기능

- **내 위치 따라가기** — 버튼을 누를 때마다 내 위치로 이동 → 따라가기 → 진행 방향으로 지도 회전 → 해제. 지도를 끌면 따라가기가 풀립니다.
- **나침반 방향 표시** — 멈춰 있을 때 폰이 향한 방향을 화살촉 또는 부채꼴로 보여 줍니다.
- **장소 검색** — 입력이 0.3초 멈추면 엔터 없이 결과를 미리 보여 줍니다. 카테고리(음식점·카페·편의점 등) 검색과 최근 검색어도 있습니다.
- **결과 목록 시트** — 목록을 끌어 올리면 검색창 바로 아래까지 펼쳐지고, 같은 손동작이 그대로 목록 스크롤로 이어집니다.
- **길찾기** — 출발지·도착지를 고르고 맞바꿀 수 있고, 최근 장소를 바로 고를 수 있습니다. 세 이동 수단을 동시에 조회해 탭마다 소요 시간을 보여 줍니다.
  - 대중교통은 경로 목록을 먼저 보여 주고, 고른 경로만 지도에 그립니다. 지하철 구간은 노선 공식 색(2호선 초록 등)으로 그립니다.
  - 자동차는 예상 택시비·통행료도 보여 줍니다.

## 기술적으로 신경 쓴 부분

| 문제 | 해결 |
|---|---|
| 글자마다 검색 API를 부르면 호출 한도를 쓰고, 늦게 온 이전 응답이 최신 결과를 덮어씀 | 0.3초 디바운스 + 새 입력이 오면 이전 Task 취소. "늦은 응답은 버린다"를 테스트로 고정하고, 처리 코드를 빼면 테스트가 실패하는 것까지 확인 |
| 검색 결과·경로에 카메라를 맞추면 위 검색창·아래 시트에 출발·도착이 가려짐 | 상단 UI와 시트가 실제로 가리는 높이를 재서 SDK 여백(`setMargins`)에 넣고 그 안쪽에 맞춤 |
| 내 위치 마커가 GPS 갱신마다 순간이동하거나, 359°→1°에서 반대로 한 바퀴 돎 | 1초(GPS 간격) 이동 애니메이션, 회전은 가까운 쪽으로 이어 붙임. 100m 넘게 뛰면 바로 이동, 정지 중 1m 미만 흔들림은 무시 |
| SwiftUI `ScrollView`로는 시트의 빈 곳 터치를 지도로 넘길 수 없음 | 시트 전체를 `UIScrollView` 하나로 만들고, 카드 위쪽 터치는 `point(inside:)`로 통과시킴 |
| 선언형 SwiftUI와 명령형 카카오맵 SDK 연결, 지도 준비 전에 들어온 명령 | `KakaoMapState`가 다리 역할을 하며, 준비 전 명령은 보관했다가 지도가 붙는 순간 실행 |

## 구조

```
MapPilot/
├ App/            AppContainer(의존성을 직접 만들어 넣는 곳 하나), 앱 진입점
├ Domain/         순수 Swift. 모델, 저장소 프로토콜, UseCase(검색어 정리·거리 제한 같은 규칙)
├ Data/           카카오 로컬·내비·길찾기 API(URLSession), DTO → 도메인 변환, UserDefaults 저장소
└ Presentation/   SwiftUI 화면 + @Observable ViewModel
   ├ Map/         지도 화면, 내 위치·따라가기(MapViewModel)
   │  ├ Kakao/    카카오맵 SDK를 감싸는 곳(SDK 타입은 이 폴더 밖으로 나가지 않음)
   │  ├ Search/   장소 검색(PlaceSearchViewModel)
   │  └ Route/    길찾기 결과·준비 화면·출발지 선택(ViewModel 3개)
   └ Common/      하단 시트, 토스트, 거리·시간 표시
```

- 의존 방향은 `Presentation → Domain ← Data`입니다. Domain은 SwiftUI·SDK를 모릅니다.
- ViewModel은 화면 상태와 일회성 이벤트(카메라 이동, 토스트)를 나눕니다. 이벤트는 `AsyncStream`으로 보냅니다.
- Swift 6 엄격한 동시성 검사를 켠 상태로 빌드합니다.

## 기술 스택

Swift 6 · SwiftUI · Observation · Swift Concurrency · Kakao Maps SDK v2 (SPM) · CoreLocation · Swift Testing

## 테스트

Swift Testing으로 단위 테스트 160여 개를 작성했습니다(UseCase, 저장소, 매퍼, ViewModel). 저장소는 가짜 구현으로 바꿔 끼우고, 실시간 검색처럼 순서가 중요한 경우는 응답 지연을 조절하는 가짜로 확인합니다.

```bash
# 시뮬레이터 이름은 `xcrun simctl list devices`로 확인
xcodebuild test -project MapPilot.xcodeproj -scheme MapPilot -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

## 실행 방법

필요 환경: Xcode 27.2(여기서 빌드·테스트 확인. 프로젝트 파일 형식이 최신이라 이전 Xcode에서는 열리지 않을 수 있음), iOS 18 이상

1. [카카오 디벨로퍼스](https://developers.kakao.com)에서 앱을 만들고, 플랫폼 → iOS에 번들 ID를 등록합니다.
2. 키 파일을 만들고 네이티브 앱 키와 REST API 키를 채웁니다.
   ```bash
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   ```
   `Secrets.xcconfig`는 git에 올라가지 않습니다.
3. `MapPilot.xcodeproj`를 열고 `MapPilot` 스킴으로 실행합니다. 시뮬레이터는 Xcode의 가상 위치(Debug → Simulate Location)를 씁니다.
