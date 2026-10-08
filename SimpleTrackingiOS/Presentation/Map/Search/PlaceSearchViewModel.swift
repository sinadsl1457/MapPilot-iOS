import Foundation
import Observation

@MainActor
@Observable
final class PlaceSearchViewModel {
    enum Source: Equatable {
        case keyword(String)
        case category(PlaceCategory)
    }

    enum Phase: Equatable {
        case loading
        case loaded([Place])
    }

    /// 검색창에 입력 중인 글자.
    var query = ""
    var isSearchPagePresented = false
    /// 검색 페이지에서 키워드 검색이 진행 중인지. 성공하면 페이지가 닫힌다.
    private(set) var isSubmitting = false

    /// 지금 지도에 보이는 결과가 어디서 왔는지. nil이면 결과 없음(시트 숨김).
    private(set) var source: Source?
    private(set) var phase: Phase?
    private(set) var selectedPlace: Place?
    private(set) var recentQueries: [String] = []

    let effects: AsyncStream<PlaceSearchEffect>

    var places: [Place] {
        if case let .loaded(places) = phase { places } else { [] }
    }

    var selectedCategory: PlaceCategory? {
        if case let .category(category) = source { category } else { nil }
    }

    var keyword: String? {
        if case let .keyword(keyword) = source { keyword } else { nil }
    }

    @ObservationIgnored private let effectContinuation: AsyncStream<PlaceSearchEffect>.Continuation
    @ObservationIgnored private let searchPlaces: SearchPlacesUseCase
    @ObservationIgnored private let searchPlacesByCategory: SearchPlacesByCategoryUseCase
    @ObservationIgnored private let recentSearches: RecentSearchesUseCase
    /// 늦게 도착한 이전 검색 결과가 최신 결과를 덮어쓰지 않게 한다.
    @ObservationIgnored private var generation = 0

    init(
        searchPlaces: SearchPlacesUseCase,
        searchPlacesByCategory: SearchPlacesByCategoryUseCase,
        recentSearches: RecentSearchesUseCase
    ) {
        self.searchPlaces = searchPlaces
        self.searchPlacesByCategory = searchPlacesByCategory
        self.recentSearches = recentSearches
        (effects, effectContinuation) = AsyncStream.makeStream()
    }

    isolated deinit {
        effectContinuation.finish()
    }

    func onAppear() async {
        recentQueries = await recentSearches.list()
    }

    // MARK: - 검색 페이지

    func openSearchPage() {
        query = keyword ?? ""
        isSearchPagePresented = true
    }

    func closeSearchPage() {
        isSearchPagePresented = false
    }

    /// 키워드 검색. 성공하면 검색 페이지를 닫고 결과를 지도에 띄운다. 실패하면 페이지에 머문다.
    /// - Parameter center: 거리 계산 기준(보통 내 위치).
    func submit(center: GeoPoint?) async {
        let generation = beginSearch()
        isSubmitting = true
        defer { if generation == self.generation { isSubmitting = false } }

        do {
            let places = try await searchPlaces(query: query, center: center)
            guard generation == self.generation else { return }
            let keyword = query.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            recentQueries = await recentSearches.add(keyword)
            isSearchPagePresented = false
            show(places, from: .keyword(keyword))
        } catch {
            guard generation == self.generation else { return }
            report(error)
        }
    }

    func searchRecent(_ recent: String, center: GeoPoint?) async {
        query = recent
        await submit(center: center)
    }

    func removeRecent(_ recent: String) async {
        recentQueries = await recentSearches.remove(recent)
    }

    func clearRecents() async {
        await recentSearches.clear()
        recentQueries = []
    }

    // MARK: - 카테고리

    /// 같은 칩을 다시 누르면 결과를 지운다.
    func toggleCategory(_ category: PlaceCategory, around center: GeoPoint) async {
        if selectedCategory == category {
            clearResults()
            return
        }
        let generation = beginSearch()
        source = .category(category)
        phase = .loading
        do {
            let places = try await searchPlacesByCategory(category, around: center)
            guard generation == self.generation else { return }
            show(places, from: .category(category))
        } catch {
            guard generation == self.generation else { return }
            clearResults()
            report(error)
        }
    }

    // MARK: - 결과·선택

    func select(_ place: Place) {
        selectedPlace = place
        effectContinuation.yield(.focus(place.location))
    }

    /// 지도 마커를 탭했을 때.
    func selectPlace(id: String) {
        guard let place = places.first(where: { $0.id == id }) else { return }
        select(place)
    }

    /// 상세에서 목록으로 돌아간다.
    func deselectPlace() {
        selectedPlace = nil
    }

    func clearResults() {
        generation += 1
        source = nil
        phase = nil
        selectedPlace = nil
        query = ""
    }

    private func beginSearch() -> Int {
        generation += 1
        selectedPlace = nil
        return generation
    }

    private func show(_ places: [Place], from source: Source) {
        self.source = source
        phase = .loaded(places)
        if !places.isEmpty {
            effectContinuation.yield(.fitCamera(places.map(\.location)))
        }
    }

    private func report(_ error: any Error) {
        guard !(error is CancellationError) else { return }
        effectContinuation.yield(.showError(error as? DomainError ?? .unknown))
    }
}
