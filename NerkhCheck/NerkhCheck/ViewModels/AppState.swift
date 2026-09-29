import SwiftUI
import Combine

private let themeKey = "theme_id"
private let appGroupId = "group.com.chandeh.app"

/// مدیریت تم فعال — ذخیره در UserDefaults و اشتراک با ویجت از طریق App Group
@MainActor
class ThemeManager: ObservableObject {
    @Published var theme: AppTheme = appThemes[0]

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    init() {
        let id = UserDefaults.standard.string(forKey: themeKey)
        theme = appTheme(id: id)
    }

    func select(_ t: AppTheme) {
        theme = t
        UserDefaults.standard.set(t.id, forKey: themeKey)
        sharedDefaults?.set(t.id, forKey: themeKey)
    }

    /// خواندن تم فعال برای ویجت (بدون نیاز به نمونه‌ی ThemeManager)
    static func currentThemeId() -> String? {
        UserDefaults(suiteName: appGroupId)?.string(forKey: themeKey)
            ?? UserDefaults.standard.string(forKey: themeKey)
    }
}

/// تنظیمات داده — کلید BRS در App Group ذخیره می‌شود تا ویجت هم به آن دسترسی داشته باشد
@MainActor
class DataSettings: ObservableObject {
    @Published var brsApiKey: String = ""
    private let defaults = UserDefaults(suiteName: appGroupId) ?? .standard

    init() {
        brsApiKey = defaults.string(forKey: Prefs.brsApiKey) ?? ""
    }

    func save(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        brsApiKey = trimmed
        defaults.set(trimmed, forKey: Prefs.brsApiKey)
    }
}

/// وضعیت قیمت‌ها
@MainActor
class PricesViewModel: ObservableObject {
    @Published var items: [PriceItem] = []
    @Published var isLoading = false
    @Published var error: String?
    /// true یعنی حداقل یک قیمت از کش (ذخیره‌شده) آمده، نه زنده
    @Published var hasStale = false

    private let defaults = UserDefaults(suiteName: appGroupId) ?? .standard

    func refresh() async {
        if isLoading { return }
        isLoading = true
        error = nil
        let key = defaults.string(forKey: Prefs.brsApiKey)
        let cache = PriceCache(defaults: defaults)
        let items = await PriceRepository.fetchPrices(brsApiKey: key, cache: cache)
        if items.isEmpty {
            self.error = PriceError.noInternet.errorDescription
        } else {
            self.items = items
            self.hasStale = items.contains { $0.isStale }
            self.error = nil
        }
        isLoading = false
    }
}
