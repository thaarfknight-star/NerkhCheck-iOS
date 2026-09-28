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

/// وضعیت قیمت‌ها
@MainActor
class PricesViewModel: ObservableObject {
    @Published var items: [PriceItem] = []
    @Published var isLoading = false
    @Published var error: String?

    func refresh() async {
        if isLoading { return }
        isLoading = true
        error = nil
        do {
            items = try await PriceRepository.fetchPrices()
        } catch {
            if let le = error as? LocalizedError, let desc = le.errorDescription {
                self.error = desc
            } else {
                self.error = "دریافت قیمت‌ها ممکن نشد؛ دوباره تلاش کنید"
            }
        }
        isLoading = false
    }
}
