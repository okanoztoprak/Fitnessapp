import SwiftUI
import WidgetKit

@main
struct PowerUpWidgetBundle: WidgetBundle {
    var body: some Widget {
        StepsWidget()
        TodayWidget()
        RestLiveActivity()
    }
}

/// Kleuren van de app; de widgets hebben geen toegang tot het app-thema.
enum WidgetTheme {
    static let accent = Color(red: 0.773, green: 0.949, blue: 0.392)
    static let good = Color(red: 0.20, green: 0.80, blue: 0.50)
    static let warn = Color(red: 1.0, green: 0.66, blue: 0.15)
    static let background = Color(red: 0.078, green: 0.145, blue: 0.133)
}
