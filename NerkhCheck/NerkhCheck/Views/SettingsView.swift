import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var dataSettings: DataSettings
    @State private var draftKey = ""

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        // داده‌ها و اینترنت ملی
                        SettingsCard {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "coloncurrencysign")
                                        .foregroundColor(themeManager.theme.accent)
                                    Text("داده‌ها و اینترنت ملی")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(appText)
                                    Spacer()
                                }
                                Text("روی اینترنت ملی، قیمت طلا و بخشی از سکه‌ها به‌صورت زنده دریافت می‌شود. برای قیمت لحظه‌ای دلار و ارزها هم، کلید رایگان BRS را وارد کنید؛ در غیر این صورت آخرین قیمت ذخیره‌شده نمایش داده می‌شود.")
                                    .font(.system(size: 13))
                                    .foregroundColor(appMuted)
                                TextField("کلید BRS API (اختیاری)", text: $draftKey)
                                    .textFieldStyle(.roundedBorder)
                                HStack {
                                    Button("ذخیره") {
                                        dataSettings.save(draftKey)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(themeManager.theme.accent)
                                    Link("دریافت کلید رایگان", destination: URL(string: "https://brsapi.ir/tsetmc-exchange-free-bourse-api-key-request/")!)
                                }
                                if !dataSettings.brsApiKey.isEmpty {
                                    Text("✓ کلید ذخیره شده و برای به‌روزرسانی بعدی استفاده می‌شود")
                                        .font(.system(size: 12))
                                        .foregroundColor(appMuted)
                                }
                            }
                        }

                        // تم‌ها
                        SettingsCard {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "paintpalette")
                                        .foregroundColor(themeManager.theme.accent)
                                    Text("تم رنگی")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(appText)
                                    Spacer()
                                }
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(appThemes) { theme in
                                        ThemeCard(
                                            theme: theme,
                                            selected: theme.id == themeManager.theme.id
                                        ) {
                                            themeManager.select(theme)
                                        }
                                    }
                                }
                            }
                        }

                        // درباره
                        SettingsCard {
                            VStack(spacing: 4) {
                                InfoRow(
                                    icon: "info.circle",
                                    title: "نسخه‌ی برنامه",
                                    value: version
                                )
                                Divider().background(appSurfaceVariant)
                                Link(destination: URL(string: "https://github.com/thaarfknight-star/NerkhCheck")!) {
                                    InfoRow(
                                        icon: "link",
                                        title: "گیت‌هاب",
                                        value: "thaarfknight-star/NerkhCheck"
                                    )
                                }
                                Divider().background(appSurfaceVariant)
                                Link(destination: URL(string: "https://t.me/tha_arf")!) {
                                    InfoRow(
                                        icon: "paperplane",
                                        title: "تلگرام",
                                        value: "@tha_arf"
                                    )
                                }
                            }
                        }

                        Text("انتقاد و پیشنهاد")
                            .font(.system(size: 13))
                            .foregroundColor(appMuted)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("تنظیمات")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            draftKey = dataSettings.brsApiKey
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack {
            content()
        }
        .padding(14)
        .background(appSurface)
        .cornerRadius(16)
    }
}

private struct ThemeCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let theme: AppTheme
    let selected: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.accent, theme.accent2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    if selected {
                        Circle()
                            .fill(appBackground.opacity(0.85))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(theme.accent)
                            )
                    }
                }
                Text(theme.nameFa)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(appText)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .background(appSurfaceVariant.opacity(0.5))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    selected ? themeManager.theme.accent : appSurfaceVariant,
                    lineWidth: selected ? 2 : 1
                )
        )
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(appMuted)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(appText)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(appMuted)
        }
        .padding(.vertical, 10)
    }
}
