import Foundation

/// خطای کلی وقتی هیچ منبعی (و کشی) در دسترس نیست
enum PriceError: LocalizedError {
    case noInternet

    var errorDescription: String? {
        "دریافت قیمت‌ها ممکن نشد؛ اتصال اینترنت را بررسی کنید و دوباره تلاش کنید"
    }
}

/// کلیدهای ذخیره‌سازی مشترک اپ و ویجت (App Group)
enum Prefs {
    static let brsApiKey = "brs_api_key"
    static let cache = "price_cache_v1"
    static let cacheAt = "price_cache_at"
}

/// کش آخرین قیمت‌های موفق — تا وقتی هیچ منبعی در دسترس نیست
/// (مثلاً ارزها روی اینترنت ملی بدون کلید BRS) اپ خالی نماند.
/// قیمت‌های کش‌شده با isStale=true برمی‌گردند تا در رابط مشخص باشند.
struct PriceCache {
    let defaults: UserDefaults
    private static let maxAge: TimeInterval = 7 * 24 * 3600

    /// فقط قیمت‌های زنده ذخیره می‌شوند؛ با کش قبلی ادغام می‌شود تا وقتی
    /// فقط بخشی از نمادها زنده‌اند، بقیه‌ی کش پاک نشود.
    func save(_ items: [PriceItem]) {
        let live = items.filter { !$0.isStale }
        guard !live.isEmpty else { return }
        var merged = load()
        for it in live { merged[it.code] = it }
        let arr: [[String: Any]] = merged.values.map { item in
            [
                "code": item.code,
                "titleFa": item.titleFa,
                "category": item.category.rawValue,
                "priceToman": item.priceToman,
                "changeToman": item.changeToman,
                "changePercent": item.changePercent,
                "updatedAt": item.updatedAt,
            ]
        }
        defaults.set(arr, forKey: Prefs.cache)
        defaults.set(Date().timeIntervalSince1970, forKey: Prefs.cacheAt)
    }

    /// بارگذاری کش؛ خالی بودن یعنی کشی نیست یا منقضی شده
    func load() -> [String: PriceItem] {
        // کش قدیمی‌تر از ۷ روز دور ریخته می‌شود
        let at = defaults.double(forKey: Prefs.cacheAt)
        guard at > 0, Date().timeIntervalSince1970 - at <= Self.maxAge else { return [:] }
        guard let arr = defaults.array(forKey: Prefs.cache) as? [[String: Any]] else { return [:] }
        let defs = Dictionary(uniqueKeysWithValues: SYMBOLS.map { ($0.code, $0) })
        var out: [String: PriceItem] = [:]
        for o in arr {
            guard let code = o["code"] as? String, let def = defs[code] else { continue }
            out[code] = PriceItem(
                code: code,
                titleFa: (o["titleFa"] as? String) ?? def.titleFa,
                category: def.category,
                priceToman: (o["priceToman"] as? NSNumber)?.int64Value ?? 0,
                changeToman: (o["changeToman"] as? NSNumber)?.int64Value ?? 0,
                changePercent: (o["changePercent"] as? NSNumber)?.doubleValue ?? 0,
                updatedAt: (o["updatedAt"] as? String) ?? "",
                isStale: true
            )
        }
        return out
    }
}

/// دریافت قیمت‌ها از چند منبع به‌صورت موازی، با ادغام بر اساس اولویت
/// (برای هر نماد، اولین منبعی که آن را داشته باشد استفاده می‌شود —
///  منابع داخلی اول تا روی اینترنت ملی هم کار کند):
///
///  ۱. BRS API (فقط اگر کلید داده شده باشد) — سرور ایران، ارز و طلا
///  ۲. نوبیتکس (بدون کلید) — سرور ایران، ارز دیجیتال (بیت‌کوین/اتریوم/تتر)
///  ۳. tala.ir (بدون کلید) — سرور ایران، طلا و بخشی از سکه‌ها
///  ۴. صفحه‌ی اصلی TGJU — هاست خارجی، همه‌ی نمادها + بیت‌کوین و تتر
///  ۵. وب‌سرویس اسنیپت TGJU — هاست خارجی، ارز و طلا و سکه
///  ۶. کوین‌گکو (بدون کلید) — هاست خارجی، ارز دیجیتال؛ فقط برای کریپتوهای
///     جامانده و با تبدیل دلار به تومان
///
/// نمادهای بدون داده‌ی زنده از کش پر می‌شوند (isStale=true) تا اپ هیچ‌وقت
/// خالی نماند.
struct PriceRepository {

    static let homepageURL = URL(string: "https://www.tgju.org/")!
    static let snippetBase =
        "http://platform.tgju.org/fa/api/webservice-snippet/?token=webservice&opts=diff,time&placeholder=tgju-data&items="
    static let talaURL = URL(string: "https://www.tala.ir/ajax/price")!
    static let brsBase = "https://api.brsapi.ir/Market/Gold_Currency.php?key="
    /// نوبیتکس — سرور ایران، بدون نیاز به کلید (ارز دیجیتال)
    static let nobitexURL = URL(string: "https://apiv2.nobitex.ir/market/stats")!
    /// کوین‌گکو — هاست خارجی، بدون نیاز به کلید (ارز دیجیتال، به دلار)
    static let coingeckoURL = URL(string:
        "https://api.coingecko.com/api/v3/simple/price" +
        "?ids=bitcoin,ethereum,tether&vs_currencies=usd&include_24hr_change=true")!

    private static let userAgent =
        "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"

    private static func fetchText(_ url: URL) async throws -> String {
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("fa-IR,fa;q=0.9", forHTTPHeaderField: "Accept-Language")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PriceError.noInternet
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// POST با بدنه‌ی JSON (برای نوبیتکس)
    private static func fetchPost(_ url: URL, jsonBody: String) async throws -> String {
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        req.httpBody = jsonBody.data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PriceError.noInternet
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func fetchPrices(brsApiKey: String? = nil, cache: PriceCache? = nil) async -> [PriceItem] {
        let key = (brsApiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        async let brs: [PriceItem]? = fetchBrs(key: key)
        async let nbBtc: PriceItem? = fetchNobitex(src: "btc", appCode: "btc")
        async let nbEth: PriceItem? = fetchNobitex(src: "eth", appCode: "eth")
        async let nbUsdt: PriceItem? = fetchNobitex(src: "usdt", appCode: "usdt")
        async let tgju: [PriceItem]? = fetchTgju()
        async let tala: [PriceItem]? = fetchTala(cache: cache)
        async let snippet: [PriceItem]? = fetchSnippet()
        // ترتیب ادغام = اولویت منابع داخلی: نوبیتکس اول (کریپتو، سرور ایران)
        let ordered = await [brs, tgju, tala, snippet]
        var merged: [String: PriceItem] = [:]
        for item in await [nbBtc, nbEth, nbUsdt] {
            if let item, merged[item.code] == nil { merged[item.code] = item }
        }
        for list in ordered {
            for item in list ?? [] where merged[item.code] == nil {
                merged[item.code] = item
            }
        }

        // فاز دوم: کوین‌گکو (خارجی) فقط برای کریپتوهای جامانده؛
        // به نرخ دلار نیاز دارد پس بعد از ادغام فاز اول اجرا می‌شود
        let dollarToman = merged["price_dollar_rl"]?.priceToman
            ?? cache?.load()["price_dollar_rl"]?.priceToman
        let missingCrypto = SYMBOLS.contains {
            $0.category == .crypto && merged[$0.code] == nil
        }
        if missingCrypto, let dollarToman, dollarToman > 0 {
            if let cg = await fetchCoinGecko(dollarToman: dollarToman) {
                for (code, item) in cg where merged[code] == nil {
                    merged[code] = item
                }
            }
        }
        let cached = cache?.load() ?? [:]
        if !merged.isEmpty { cache?.save(Array(merged.values)) }
        // ترتیب نهایی همیشه همان ترتیب SYMBOLS
        return SYMBOLS.compactMap { merged[$0.code] ?? cached[$0.code] }
    }

    // MARK: - منابع

    private static func fetchBrs(key: String) async -> [PriceItem]? {
        guard !key.isEmpty,
              let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: brsBase + encoded),
              let text = try? await fetchText(url) else { return nil }
        let items = parseBrs(text)
        return items.isEmpty ? nil : items
    }

    private static func fetchTgju() async -> [PriceItem]? {
        // پارامتر ضدکش تا همیشه تازه‌ترین صفحه گرفته شود
        var comps = URLComponents(url: homepageURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970)))]
        guard let url = comps.url,
              let html = try? await fetchText(url),
              let items = try? parseHomepage(html),
              !items.isEmpty else { return nil }
        return items
    }

    private static func fetchTala(cache: PriceCache?) async -> [PriceItem]? {
        guard let text = try? await fetchText(talaURL) else { return nil }
        // اعتبارسنجی در برابر کش: فید tala.ir گاهی مقادیر خراب می‌دهد
        let known = cache?.load() ?? [:]
        let items = parseTala(text).filter { talaPlausible($0, cached: known) }
        return items.isEmpty ? nil : items
    }

    private static func fetchSnippet() async -> [PriceItem]? {
        // اسنیپت فقط نمادهای غیرکریپتو را می‌شناسد و نگاشتش موقعیتی است؛
        // پس کریپتوها از درخواست حذف می‌شوند
        let defs = SYMBOLS.filter { $0.category != .crypto }
        let itemsParam = defs.map { $0.code }.joined(separator: ",")
        guard let url = URL(string: snippetBase + itemsParam),
              let body = try? await fetchText(url) else { return nil }
        let items = (try? parseSnippet(body, defs: defs)) ?? []
        return items.isEmpty ? nil : items
    }

    private static func fetchNobitex(src: String, appCode: String) async -> PriceItem? {
        guard let text = try? await fetchPost(
            nobitexURL, jsonBody: "{\"srcCurrency\":\"\(src)\",\"dstCurrency\":\"rls\"}"
        ) else { return nil }
        return parseNobitex(text, appCode: appCode)
    }

    private static func fetchCoinGecko(dollarToman: Int64) async -> [String: PriceItem]? {
        guard let text = try? await fetchText(coingeckoURL) else { return nil }
        let items = parseCoinGecko(text, dollarToman: dollarToman)
        return items.isEmpty ? nil : items
    }

    /**
     * تور ایمنی tala.ir: مقدار باید مثبت، داخل کرانه‌ی مطلق، و (اگر کشی از
     * همین نماد هست) حداکثر ۵۰٪ با آخرین قیمت موفق اختلاف داشته باشد.
     */
    private static func talaPlausible(_ item: PriceItem, cached: [String: PriceItem]) -> Bool {
        guard item.priceToman > 0 else { return false }
        if let (lo, hi) = talaBounds[item.code], !(lo...hi).contains(item.priceToman) { return false }
        if let c = cached[item.code]?.priceToman, c > 0 {
            return Double(abs(item.priceToman - c)) / Double(c) <= 0.5
        }
        return true
    }

    // MARK: - Regex helpers

    private static func makeRegex(_ pattern: String) -> NSRegularExpression {
        // الگوها ثابت و معتبرند
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        )
    }

    private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        let ns = text as NSString
        return makeRegex(pattern).firstMatch(
            in: text,
            range: NSRange(location: 0, length: ns.length)
        )
    }

    private static func group(_ m: NSTextCheckingResult, _ i: Int, in text: String) -> String {
        (text as NSString).substring(with: m.range(at: i))
    }

    // MARK: - TGJU: صفحه‌ی اصلی

    /**
     * پارس صفحه‌ی اصلی tgju.org — هر سطر:
     * <tr data-market-nameslug="price_dollar_rl" ...>
     *   <td class="nf">2,442,150</td>
     *   <td class="nf"><span class="high">(3.92%) 92,150</span></td>
     *   ...
     *   <td>۱۴:۱۰:۳۱</td>
     * مبالغ به ریال‌اند -> تقسیم بر ۱۰ برای تومان. جهت تغییر از کلاس high/low.
     */
    static func parseHomepage(_ html: String) throws -> [PriceItem] {
        var items: [PriceItem] = []
        let fiatDefs = SYMBOLS.filter { $0.category != .crypto }
        for def in fiatDefs {
            let rowPattern = "<tr[^>]*data-market-nameslug=\"" + def.code + "\".*?</tr>"
            guard let rowMatch = firstMatch(rowPattern, in: html) else { continue }
            let row = group(rowMatch, 0, in: html)

            guard let pm = firstMatch("<td[^>]*>([\\d,]+)</td>", in: row),
                  let priceRial = Int64(group(pm, 1, in: row).replacingOccurrences(of: ",", with: ""))
            else { continue }

            var sign: Int64 = 1
            var pct: Double = 0
            var changeRial: Int64 = 0
            if let cm = firstMatch(
                "<span class=\"(high|low)\">\\(([-\\d.]+)%\\)\\s*(-?[\\d,]+)</span>",
                in: row
            ) {
                let dir = group(cm, 1, in: row)
                pct = Double(group(cm, 2, in: row)) ?? 0
                changeRial = Int64(group(cm, 3, in: row).replacingOccurrences(of: ",", with: "")) ?? 0
                sign = (dir == "low") ? -1 : 1
            }

            var time = ""
            if let tm = firstMatch(
                "<td[^>]*>([\\d۰-۹]{1,2}:[\\d۰-۹]{2}(?::[\\d۰-۹]{2})?)</td>",
                in: row
            ) {
                time = group(tm, 1, in: row)
            }

            items.append(PriceItem(
                code: def.code,
                titleFa: def.titleFa,
                category: def.category,
                priceToman: priceRial / 10,
                changeToman: sign * (changeRial / 10),
                changePercent: Double(sign) * abs(pct),
                updatedAt: time
            ))
        }
        if items.count < fiatDefs.count / 2 {
            throw PriceError.noInternet
        }

        // کریپتوهای زنده‌ی صفحه‌ی اصلی (سطرهای فشرده با data-price)؛
        // بیت‌کوین به دلار است و با نرخ دلار به تومان تبدیل می‌شود، تتر به ریال
        let dollarToman = items.first(where: { $0.code == "price_dollar_rl" })?.priceToman ?? 0
        let cryptoTgju: [(slug: String, code: String, inUsd: Bool)] = [
            ("crypto-bitcoin", "btc", true),
            ("crypto-tether", "usdt", false),
        ]
        let defsByCode = Dictionary(uniqueKeysWithValues: SYMBOLS.map { ($0.code, $0) })
        for (slug, code, inUsd) in cryptoTgju {
            guard let def = defsByCode[code] else { continue }
            let rowPattern = "<tr[^>]*data-market-nameslug=\"" + slug + "\".*?</tr>"
            guard let rowMatch = firstMatch(rowPattern, in: html) else { continue }
            let row = group(rowMatch, 0, in: html)
            guard let pm = firstMatch("data-price=\"([\\d.,]+)\"", in: row),
                  let priceRaw = Double(group(pm, 1, in: row).replacingOccurrences(of: ",", with: ""))
            else { continue }

            var sign: Int64 = 1
            var pct: Double = 0
            var changeRaw: Double = 0
            if let cm = firstMatch(
                "<span class=\"(high|low)\">\\(([-\\d.]+)%\\)\\s*(-?[\\d,]+)</span>",
                in: row
            ) {
                let dir = group(cm, 1, in: row)
                pct = Double(group(cm, 2, in: row)) ?? 0
                changeRaw = Double(group(cm, 3, in: row).replacingOccurrences(of: ",", with: "")) ?? 0
                sign = (dir == "low") ? -1 : 1
            }

            var time = ""
            if let tm = firstMatch(
                "<td[^>]*>([\\d۰-۹]{1,2}:[\\d۰-۹]{2}(?::[\\d۰-۹]{2})?)</td>",
                in: row
            ) {
                time = group(tm, 1, in: row)
            }

            let priceToman: Int64
            let changeToman: Int64
            if inUsd {
                guard dollarToman > 0 else { continue }
                priceToman = Int64(priceRaw * Double(dollarToman))
                changeToman = sign * Int64(changeRaw * Double(dollarToman))
            } else {
                // ریال -> تومان
                priceToman = Int64(priceRaw / 10)
                changeToman = sign * Int64(changeRaw / 10)
            }
            items.append(PriceItem(
                code: def.code,
                titleFa: def.titleFa,
                category: def.category,
                priceToman: priceToman,
                changeToman: changeToman,
                changePercent: Double(sign) * abs(pct),
                updatedAt: time
            ))
        }
        return items
    }

    // MARK: - TGJU: وب‌سرویس اسنیپت

    /**
     * پارس وب‌سرویس اسنیپت (جایگزین) — نمونه سطر:
     *   | سکه امامی | 2,465,050,000 | (2.49%) 60,000,000 | ۱۴:۱۰:۴۹ |
     * نگاشت موقعیتی است: ترتیب سطرها همان ترتیب defs درخواستی است.
     */
    static func parseSnippet(_ body: String, defs: [SymbolDef]) throws -> [PriceItem] {
        let pattern = "\\|\\s*([^|]+?)\\s*\\|\\s*([\\d,]+)\\s*\\|\\s*\\(?\\s*(-?[\\d.]+)\\s*%\\s*\\)?\\s*(-?[\\d,]+)\\s*\\|\\s*([^|]*?)\\s*\\|"
        let ns = body as NSString
        let matches = makeRegex(pattern).matches(
            in: body,
            range: NSRange(location: 0, length: ns.length)
        )
        if matches.isEmpty {
            throw PriceError.noInternet
        }
        return matches.prefix(defs.count).enumerated().map { index, m in
            let def = defs[index]
            let priceRial = Int64(group(m, 2, in: body).replacingOccurrences(of: ",", with: "")) ?? 0
            let pct = Double(group(m, 3, in: body)) ?? 0
            let chgRial = Int64(group(m, 4, in: body).replacingOccurrences(of: ",", with: "")) ?? 0
            let signedPct = chgRial < 0 ? -abs(pct) : abs(pct)
            let time = group(m, 5, in: body).trimmingCharacters(in: .whitespaces)
            return PriceItem(
                code: def.code,
                titleFa: def.titleFa,
                category: def.category,
                priceToman: priceRial / 10,
                changeToman: chgRial / 10,
                changePercent: signedPct,
                updatedAt: time
            )
        }
    }

    // MARK: - نوبیتکس: سرور ایران (ارز دیجیتال)

    /**
     * پارس پاسخ POST https://apiv2.nobitex.ir/market/stats
     * مبالغ به ریال‌اند -> تقسیم بر ۱۰ برای تومان.
     */
    static func parseNobitex(_ text: String, appCode: String) -> PriceItem? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["status"] as? String) == "ok",
              let stats = json["stats"] as? [String: Any],
              let s = stats.values.first as? [String: Any],
              let latestStr = s["latest"] as? String,
              let latestRial = Double(latestStr),
              latestRial > 0,
              let def = SYMBOLS.first(where: { $0.code == appCode })
        else { return nil }
        let pct = Double(s["dayChange"] as? String ?? "") ?? 0
        let priceToman = Int64(latestRial / 10)
        return PriceItem(
            code: def.code,
            titleFa: def.titleFa,
            category: def.category,
            priceToman: priceToman,
            changeToman: Int64(Double(priceToman) * pct / 100),
            changePercent: pct,
            updatedAt: ""
        )
    }

    // MARK: - کوین‌گکو: هاست خارجی (ارز دیجیتال)

    /**
     * پارس پاسخ CoinGecko — قیمت‌ها به دلارند و با نرخ دلار به تومان
     * تبدیل می‌شوند. فقط برای کریپتوهای جامانده از منابع دیگر صدا زده می‌شود.
     */
    static func parseCoinGecko(_ text: String, dollarToman: Int64) -> [String: PriceItem] {
        guard dollarToman > 0,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        let map = ["bitcoin": "btc", "ethereum": "eth", "tether": "usdt"]
        let defsByCode = Dictionary(uniqueKeysWithValues: SYMBOLS.map { ($0.code, $0) })
        var out: [String: PriceItem] = [:]
        for (cgId, appCode) in map {
            guard let o = json[cgId] as? [String: Any],
                  let usd = o["usd"] as? Double, usd > 0,
                  let def = defsByCode[appCode]
            else { continue }
            let pct = o["usd_24h_change"] as? Double ?? 0
            let priceToman = Int64(usd * Double(dollarToman))
            out[appCode] = PriceItem(
                code: def.code,
                titleFa: def.titleFa,
                category: def.category,
                priceToman: priceToman,
                changeToman: Int64(Double(priceToman) * pct / 100),
                changePercent: pct,
                updatedAt: ""
            )
        }
        return out
    }

    // MARK: - tala.ir: سرور ایران (طلا و بخشی از سکه‌ها)

    /**
     * پارس خروجی https://www.tala.ir/ajax/price — نمونه:
     *   "gold_18k": {"v": "24,988,900", "d": "9,234 (0.04%)",
     *                "jdate": "14:59 1405/07/07", ...}
     *
     * نکته‌های مهم (بررسی‌شده با داده‌ی واقعی):
     *  - مقادیر v همین‌جا به تومان‌اند (تقسیم لازم نیست).
     *  - گاهی علامت منفیِ تغییر روزانه به اولِ v چسبیده؛ مقدار واقعی قدرمطلق است.
     *  - فید سکه‌ی امامی/بهار (sekke-jad/gad) خراب است (خود سایت هم «-» نشان
     *    می‌دهد و مقدارش ~۳۰٪ با بازار اختلاف دارد)؛ پس نگاشت نمی‌شوند.
     */
    static func parseTala(_ text: String) -> [PriceItem] {
        guard let data = text.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return [] }
        let defs = Dictionary(uniqueKeysWithValues: SYMBOLS.map { ($0.code, $0) })
        var out: [PriceItem] = []
        for (talaKey, appCode) in talaCodeMap {
            guard let def = defs[appCode] else { continue }
            let section = talaKey.hasPrefix("gold_") ? "gold" : "sekke"
            guard let obj = (root[section] as? [String: Any])?[talaKey] as? [String: Any] else { continue }
            let vStr = (obj["v"] as? String) ?? ""
            guard let raw = Int64(vStr.replacingOccurrences(of: ",", with: "")), raw != 0 else { continue }
            let priceToman = abs(raw)
            // d نمونه: "-100,000 (0.05%)"
            let d = (obj["d"] as? String) ?? ""
            var changeToman: Int64 = 0
            var pct: Double = 0
            if let dm = firstMatch("(-?[\\d,]+)\\s*\\(([-\\d.]+)%\\)", in: d) {
                changeToman = Int64(group(dm, 1, in: d).replacingOccurrences(of: ",", with: "")) ?? 0
                pct = Double(group(dm, 2, in: d)) ?? 0
            }
            let sign: Int64 = (changeToman < 0 || pct < 0) ? -1 : 1
            let jdate = (obj["jdate"] as? String) ?? ""
            let time = jdate.split(separator: " ").first.map(String.init) ?? ""
            out.append(PriceItem(
                code: def.code,
                titleFa: def.titleFa,
                category: def.category,
                priceToman: priceToman,
                changeToman: changeToman,
                changePercent: Double(sign) * abs(pct),
                updatedAt: time
            ))
        }
        return out
    }

    // MARK: - BRS API: سرور ایران (همه‌ی نمادها، نیازمند کلید)

    /**
     * پارس خروجی https://api.brsapi.ir/Market/Gold_Currency.php?key=...
     * مبالغ همین‌جا به تومان‌اند (تبدیل لازم نیست).
     */
    static func parseBrs(_ text: String) -> [PriceItem] {
        guard let data = text.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return [] }
        let successful: Bool = {
            if let b = root["successful"] as? Bool { return b }
            if let n = root["successful"] as? NSNumber { return n.boolValue }
            return true
        }()
        guard successful else { return [] }
        var bySymbol: [String: [String: Any]] = [:]
        for arrName in ["gold", "currency"] {
            guard let arr = root[arrName] as? [[String: Any]] else { continue }
            for o in arr {
                if let s = o["symbol"] as? String, bySymbol[s] == nil { bySymbol[s] = o }
            }
        }
        guard !bySymbol.isEmpty else { return [] }
        let defs = Dictionary(uniqueKeysWithValues: SYMBOLS.map { ($0.code, $0) })
        return brsCodeMap.compactMap { brsSym, appCode in
            guard let o = bySymbol[brsSym], let def = defs[appCode] else { return nil }
            let price = money(o["price"])
            guard price > 0 else { return nil }
            return PriceItem(
                code: def.code,
                titleFa: def.titleFa,
                category: def.category,
                priceToman: price,
                changeToman: money(o["change_value"]),
                changePercent: doubleFlex(o["change_percent"]),
                updatedAt: (o["time"] as? String) ?? ""
            )
        }
    }

    /** خواندن عدد که ممکن است Number یا رشته‌ی «1,234» باشد */
    private static func money(_ v: Any?) -> Int64 {
        if let n = v as? NSNumber { return n.int64Value }
        if let s = v as? String { return Int64(s.replacingOccurrences(of: ",", with: "")) ?? 0 }
        return 0
    }

    private static func doubleFlex(_ v: Any?) -> Double {
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s.replacingOccurrences(of: ",", with: "")) ?? 0 }
        return 0
    }

    // MARK: - نگاشت‌ها

    /** نگاشت کلیدهای tala.ir به کد نمادهای برنامه.
     *  سکه‌ی امامی/بهار عمداً نیست: فیدشان خراب است. */
    private static let talaCodeMap: [(String, String)] = [
        ("gold_18k", "geram18"),
        ("gold_24k", "geram24"),
        ("gold_bazartehran", "mesghal"),
        ("sekke-nim", "nim"),
        ("sekke-rob", "rob"),
        ("sekke-grm", "gerami"),
    ]

    /** کرانه‌ی قابل‌قبول قیمت tala.ir به تومان */
    private static let talaBounds: [String: (Int64, Int64)] = [
        "geram18": (5_000_000, 120_000_000),
        "geram24": (7_000_000, 160_000_000),
        "mesghal": (20_000_000, 520_000_000),
        "nim": (30_000_000, 600_000_000),
        "rob": (15_000_000, 300_000_000),
        "gerami": (8_000_000, 180_000_000),
    ]

    /** نگاشت نمادهای BRS به کد نمادهای برنامه */
    private static let brsCodeMap: [(String, String)] = [
        ("USD", "price_dollar_rl"),
        ("EUR", "price_eur"),
        ("GBP", "price_gbp"),
        ("AED", "price_aed"),
        ("TRY", "price_try"),
        ("CHF", "price_chf"),
        ("CNY", "price_cny"),
        ("JPY", "price_jpy"),
        ("CAD", "price_cad"),
        ("AUD", "price_aud"),
        ("IR_GOLD_18K", "geram18"),
        ("IR_GOLD_24K", "geram24"),
        ("IR_GOLD_MELTED", "mesghal"),
        ("IR_COIN_EMAMI", "sekee"),
        ("IR_COIN_BAHAR", "sekeb"),
        ("IR_COIN_HALF", "nim"),
        ("IR_COIN_QUARTER", "rob"),
        ("IR_COIN_1G", "gerami"),
    ]
}
