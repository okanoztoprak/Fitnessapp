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
    static let accent = Color(red: 0.80, green: 0.98, blue: 0.27)
    static let good = Color(red: 0.20, green: 0.80, blue: 0.50)
    static let warn = Color(red: 1.0, green: 0.66, blue: 0.15)
    static let background = Color(red: 0.07, green: 0.07, blue: 0.085)
}
