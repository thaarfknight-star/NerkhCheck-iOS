import Foundation

private let faDigits: [Character] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

extension String {
    /// تبدیل ارقام انگلیسی به فارسی
    func toFaDigits() -> String {
        String(self.map { c in
            if let v = c.wholeNumberValue, (0...9).contains(v) {
                return faDigits[v]
            }
            return c
        })
    }
}

extension Int64 {
    /// 125000 -> ۱۲۵٬۰۰۰
    func toFaToman() -> String {
        var s = String(self)
        var negative = false
        if s.hasPrefix("-") {
            negative = true
            s = String(s.dropFirst())
        }
        var out = ""
        var count = 0
        for ch in s.reversed() {
            out.append(ch)
            count += 1
            if count % 3 == 0 && count != s.count {
                out.append("٬")
            }
        }
        var res = String(out.reversed())
        if negative {
            res = "-" + res
        }
        return res.toFaDigits()
    }
}

extension Double {
    /// 2.07 -> ٪۲٫۰۷
    func toFaPercent() -> String {
        let rounded = (abs(self) * 100).rounded() / 100
        var s: String
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            s = String(Int64(rounded))
        } else {
            s = String(format: "%.2f", rounded)
            while s.hasSuffix("0") { s = String(s.dropLast()) }
            if s.hasSuffix(".") { s = String(s.dropLast()) }
        }
        let fa = s.toFaDigits().replacingOccurrences(of: ".", with: "٫")
        return "٪" + fa
    }

    /// برای نتایج تبدیل: اعداد بزرگ با جداکننده، اعداد کوچک با اعشار
    func toFaSmart() -> String {
        if self >= 1000 || self == 0 {
            return Int64(self).toFaToman()
        }
        var s = String(format: "%.4f", self)
        while s.hasSuffix("0") { s = String(s.dropLast()) }
        if s.hasSuffix(".") { s = String(s.dropLast()) }
        return s.toFaDigits().replacingOccurrences(of: ".", with: "٫")
    }
}
