import SwiftUI

@main
struct NerkhCheckApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var pricesVM = PricesViewModel()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(themeManager)
                .environmentObject(pricesVM)
                .environment(\.locale, Locale(identifier: "fa_IR"))
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
    }
}
