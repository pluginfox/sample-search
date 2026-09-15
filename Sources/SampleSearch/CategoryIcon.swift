import DrumIcons
import SwiftUI
import SampleSearchKit

/// Category glyph: the hand-drawn kick and tom, SF Symbols for the rest.
struct CategoryIcon: View {
    var category: DrumCategory

    var body: some View {
        switch category {
        case .kick: Image(nsImage: DrumIcon.kick.image(pointSize: 18)).renderingMode(.template)
        case .tom: Image(nsImage: DrumIcon.tom.image(pointSize: 18)).renderingMode(.template)
        default: Image(systemName: category.symbol)
        }
    }
}
