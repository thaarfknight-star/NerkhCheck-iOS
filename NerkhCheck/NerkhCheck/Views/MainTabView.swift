import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            PriceListView()
                .tabItem { Label("قیمت‌ها", systemImage: "list.bullet") }
                .tag(0)
            ConverterView()
                .tabItem { Label("تبدیل", systemImage: "arrow.left.arrow.right") }
                .tag(1)
            SettingsView()
                .tabItem { Label("تنظیمات", systemImage: "gear") }
                .tag(2)
        }
        .tint(themeManager.theme.accent)
    }
}
