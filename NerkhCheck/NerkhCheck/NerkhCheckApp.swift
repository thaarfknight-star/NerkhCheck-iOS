import SwiftUI

@main
struct NerkhCheckApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var pricesVM = PricesViewModel()
    @StateObject private var dataSettings = DataSettings()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(themeManager)
                .environmentObject(pricesVM)
                .environmentObject(dataSettings)
                .environment(\.locale, Locale(identifier: "fa_IR"))
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
    }
}
