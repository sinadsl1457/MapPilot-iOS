import SwiftUI

/// 검색창 아래 가로로 스크롤되는 카테고리 칩.
struct CategoryChips: View {
    let selected: PlaceCategory?
    let onTap: (PlaceCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlaceCategory.allCases, id: \.self) { category in
                    let isSelected = category == selected
                    Button {
                        onTap(category)
                    } label: {
                        Label(category.title, systemImage: category.symbolName)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .background(isSelected ? Color.accentColor : Color(.systemBackground), in: Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}
