import Foundation

/// دسته‌بندی نمادها
enum Category: String, Hashable {
    case currency, gold, coin

    var titleFa: String {
        switch self {
        case .currency: return "ارزها"
        case .gold: return "طلا"
        case .coin: return "سکه"
        }
    }
}

/// تعریف یک نماد: کد داخلی TGJU + عنوان فارسی
struct SymbolDef {
    let code: String
    let titleFa: String
    let category: Category
}

/// نمادهای تحت پوشش — ترتیب این لیست همان ترتیبی است که به وب‌سرویس
/// TGJU ارسال می‌شود و سطرهای پاسخ هم به همین ترتیب برمی‌گردند.
let SYMBOLS: [SymbolDef] = [
    // ارزها — بازار آزاد
    SymbolDef(code: "price_dollar_rl", titleFa: "دلار آمریکا", category: .currency),
    SymbolDef(code: "price_eur", titleFa: "یورو", category: .currency),
    SymbolDef(code: "price_gbp", titleFa: "پوند انگلیس", category: .currency),
    SymbolDef(code: "price_aed", titleFa: "درهم امارات", category: .currency),
    SymbolDef(code: "price_try", titleFa: "لیر ترکیه", category: .currency),
    SymbolDef(code: "price_chf", titleFa: "فرانک سوئیس", category: .currency),
    SymbolDef(code: "price_cny", titleFa: "یوان چین", category: .currency),
    SymbolDef(code: "price_jpy", titleFa: "ین ژاپن", category: .currency),
    SymbolDef(code: "price_cad", titleFa: "دلار کانادا", category: .currency),
    SymbolDef(code: "price_aud", titleFa: "دلار استرالیا", category: .currency),
    // طلا
    SymbolDef(code: "geram18", titleFa: "طلای ۱۸ عیار", category: .gold),
    SymbolDef(code: "geram24", titleFa: "طلای ۲۴ عیار", category: .gold),
    SymbolDef(code: "mesghal", titleFa: "مثقال طلا", category: .gold),
    // سکه
    SymbolDef(code: "sekee", titleFa: "سکه امامی", category: .coin),
    SymbolDef(code: "sekeb", titleFa: "سکه بهار آزادی", category: .coin),
    SymbolDef(code: "nim", titleFa: "نیم‌سکه", category: .coin),
    SymbolDef(code: "rob", titleFa: "ربع‌سکه", category: .coin),
    SymbolDef(code: "gerami", titleFa: "سکه گرمی", category: .coin),
]

/// یک قلم قیمت — همه‌ی مبالغ به تومان.
/// isStale یعنی این قیمت زنده نیست و از حافظه‌ی (کش) برنامه آمده است.
struct PriceItem: Identifiable, Hashable {
    let code: String
    let titleFa: String
    let category: Category
    let priceToman: Int64
    let changeToman: Int64
    let changePercent: Double
    let updatedAt: String
    let isStale: Bool

    init(
        code: String,
        titleFa: String,
        category: Category,
        priceToman: Int64,
        changeToman: Int64,
        changePercent: Double,
        updatedAt: String,
        isStale: Bool = false
    ) {
        self.code = code
        self.titleFa = titleFa
        self.category = category
        self.priceToman = priceToman
        self.changeToman = changeToman
        self.changePercent = changePercent
        self.updatedAt = updatedAt
        self.isStale = isStale
    }

    var id: String { code }
}
