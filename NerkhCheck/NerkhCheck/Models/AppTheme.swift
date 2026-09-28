import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

/// سبز/قرمز مخصوص اعداد روی پس‌زمینه‌ی تیره
let profitGreen = Color(hex: 0x34D399)
let lossRed = Color(hex: 0xF87171)

/// رنگ‌های پایه‌ی اپ (تم تیره)
let appBackground = Color(hex: 0x0A0E1A)
let appSurface = Color(hex: 0x131B30)
let appSurfaceVariant = Color(hex: 0x1B2440)
let appMuted = Color(hex: 0x8B93A7)
let appText = Color(hex: 0xF4F6FB)

/// یک تم رنگی اپ: دو لهجه‌ی ترکیبی + گرادیان کارت ویژه
struct AppTheme: Identifiable, Hashable {
    let id: String
    let nameFa: String
    let accent: Color
    let accent2: Color
    let heroTop: Color
    let heroBottom: Color

    // Color is not Hashable; hash by id only
    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// شش تم ترکیب‌رنگی
let appThemes: [AppTheme] = [
    AppTheme(
        id: "aurora",
        nameFa: "شفق قطبی",
        accent: Color(hex: 0x2DD4BF),
        accent2: Color(hex: 0xA78BFA),
        heroTop: Color(hex: 0x0B2E2A),
        heroBottom: Color(hex: 0x1E1B3D)
    ),
    AppTheme(
        id: "volcano",
        nameFa: "آتشفشان",
        accent: Color(hex: 0xFB923C),
        accent2: Color(hex: 0xF43F5E),
        heroTop: Color(hex: 0x3A1E0B),
        heroBottom: Color(hex: 0x3A0F1E)
    ),
    AppTheme(
        id: "galaxy",
        nameFa: "کهکشان",
        accent: Color(hex: 0x818CF8),
        accent2: Color(hex: 0xF472B6),
        heroTop: Color(hex: 0x1A1B3D),
        heroBottom: Color(hex: 0x2E1030)
    ),
    AppTheme(
        id: "beach",
        nameFa: "ساحل",
        accent: Color(hex: 0x38BDF8),
        accent2: Color(hex: 0xFBBF24),
        heroTop: Color(hex: 0x0B2740),
        heroBottom: Color(hex: 0x2E2410)
    ),
    AppTheme(
        id: "jungle",
        nameFa: "جنگل",
        accent: Color(hex: 0x34D399),
        accent2: Color(hex: 0xA3E635),
        heroTop: Color(hex: 0x0B2E1E),
        heroBottom: Color(hex: 0x232E0B)
    ),
    AppTheme(
        id: "neon",
        nameFa: "نئون",
        accent: Color(hex: 0x22D3EE),
        accent2: Color(hex: 0xE879F9),
        heroTop: Color(hex: 0x0A2E38),
        heroBottom: Color(hex: 0x2E1040)
    ),
]

func appTheme(id: String?) -> AppTheme {
    appThemes.first(where: { $0.id == id }) ?? appThemes[0]
}
