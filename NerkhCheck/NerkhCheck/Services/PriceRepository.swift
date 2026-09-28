import Foundation

/// خطاهای قابل‌فهم فارسی
enum PriceError: LocalizedError, Equatable {
    case serverBusy
    case noInternet
    case incomplete
    case unreadable

    var errorDescription: String? {
        switch self {
        case .serverBusy:
            return "سرور قیمت‌ها موقتاً در دسترس نیست؛ چند دقیقه دیگر تلاش کنید"
        case .noInternet:
            return "اتصال اینترنت را بررسی کنید و دوباره تلاش کنید"
        case .incomplete:
            return "پاسخ سرور ناقص بود"
        case .unreadable:
            return "پاسخ سرور قابل خواندن نبود"
        }
    }
}

/// دریافت قیمت‌ها از TGJU.
///
/// منبع اصلی: صفحه‌ی اصلی www.tgju.org (ساخت‌یافته، داخل <tr data-market-nameslug="...">)
/// منبع جایگزین: وب‌سرویس عمومی platform.tgju.org (گاهی 500 می‌دهد)
struct PriceRepository {

    static let homepageURL = URL(string: "https://www.tgju.org/")!
    static let snippetBase =
        "http://platform.tgju.org/fa/api/webservice-snippet/?token=webservice&opts=diff,time&placeholder=tgju-data&items="

    private static let userAgent =
        "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"

    private static func fetchText(_ url: URL) async throws -> String {
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("fa-IR,fa;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if http.statusCode >= 500 {
                throw PriceError.serverBusy
            }
            throw PriceError.unreadable
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func fetchPrices() async throws -> [PriceItem] {
        do {
            let html = try await fetchText(homepageURL)
            return try parseHomepage(html)
        } catch {
            let first = error
            do {
                let itemsParam = SYMBOLS.map { $0.code }.joined(separator: ",")
                let body = try await fetchText(URL(string: snippetBase + itemsParam)!)
                return try parseSnippet(body)
            } catch {
                throw friendlyError(error, first: first)
            }
        }
    }

    private static func friendlyError(_ e: Error, first: Error?) -> Error {
        if let pe = e as? PriceError, pe == .serverBusy { return e }
        if let pe = first as? PriceError, pe == .serverBusy { return first! }
        let eDomain = (e as NSError).domain
        let fDomain = (first as NSError?)?.domain
        if eDomain == NSURLErrorDomain || fDomain == NSURLErrorDomain {
            return PriceError.noInternet
        }
        return e
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
        for def in SYMBOLS {
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
        if items.count < SYMBOLS.count / 2 {
            throw PriceError.incomplete
        }
        return items
    }

    /**
     * پارس وب‌سرویس اسنیپت (جایگزین) — نمونه سطر:
     *   | سکه امامی | 2,465,050,000 | (2.49%) 60,000,000 | ۱۴:۱۰:۴۹ |
     */
    static func parseSnippet(_ body: String) throws -> [PriceItem] {
        let pattern = "\\|\\s*([^|]+?)\\s*\\|\\s*([\\d,]+)\\s*\\|\\s*\\(?\\s*(-?[\\d.]+)\\s*%\\s*\\)?\\s*(-?[\\d,]+)\\s*\\|\\s*([^|]*?)\\s*\\|"
        let ns = body as NSString
        let matches = makeRegex(pattern).matches(
            in: body,
            range: NSRange(location: 0, length: ns.length)
        )
        if matches.isEmpty {
            throw PriceError.unreadable
        }
        return matches.prefix(SYMBOLS.count).enumerated().map { index, m in
            let def = SYMBOLS[index]
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
}
