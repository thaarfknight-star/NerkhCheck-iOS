import SwiftUI

struct PriceListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var pricesVM: PricesViewModel

    private let categories: [Category] = [.currency, .gold, .coin]

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground.ignoresSafeArea()

                if pricesVM.isLoading && pricesVM.items.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(themeManager.theme.accent)
                        Text("در حال دریافت قیمت‌ها...")
                            .foregroundColor(appMuted)
                            .font(.system(size: 14))
                    }
                } else if let err = pricesVM.error, pricesVM.items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 56))
                            .foregroundColor(appMuted)
                        Text(err)
                            .font(.system(size: 15))
                            .foregroundColor(appText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("تلاش دوباره") {
                            Task { await pricesVM.refresh() }
                        }
                        .buttonStyle(.bordered)
                        .tint(themeManager.theme.accent)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if let dollar = pricesVM.items.first(where: { $0.code == "price_dollar_rl" }) {
                                HeroCard(item: dollar)
                            }
                            // اعلام وضعیت: وقتی بخشی از قیمت‌ها زنده نیستند
                            if pricesVM.hasStale {
                                HStack(spacing: 8) {
                                    Image(systemName: "wifi.slash")
                                        .font(.system(size: 14))
                                        .foregroundColor(appMuted)
                                    Text("برخی قیمت‌ها به‌روز نشدند و از حافظه نمایش داده می‌شوند")
                                        .font(.system(size: 12))
                                        .foregroundColor(appMuted)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(appSurfaceVariant.opacity(0.6))
                                .cornerRadius(12)
                            }
                            ForEach(categories, id: \.self) { cat in
                                let list = pricesVM.items.filter {
                                    $0.category == cat && $0.code != "price_dollar_rl"
                                }
                                if !list.isEmpty {
                                    CategoryHeader(title: cat.titleFa)
                                    ForEach(list) { item in
                                        PriceRow(item: item)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .refreshable {
                        await pricesVM.refresh()
                    }
                }

                if pricesVM.isLoading && !pricesVM.items.isEmpty {
                    ProgressView()
                        .tint(themeManager.theme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("NerkhCheck")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await pricesVM.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            if pricesVM.items.isEmpty {
                await pricesVM.refresh()
            }
        }
    }
}

/// کارت ویژه‌ی دلار با گرادیان تم
struct HeroCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: PriceItem

    var body: some View {
        let theme = themeManager.theme
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(theme.accent2)
                    .frame(width: 8, height: 8)
                Text("\(item.titleFa) • بازار آزاد")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.accent)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            HStack(alignment: .bottom, spacing: 6) {
                Text(item.priceToman.toFaToman())
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(.white)
                Text("تومان")
                    .font(.system(size: 14))
                    .foregroundColor(appMuted)
                    .padding(.bottom, 6)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            HStack(spacing: 8) {
                ChangePill(item: item, fontSize: 14)
                if !item.updatedAt.isEmpty {
                    Text("به‌روزرسانی \(item.updatedAt.toFaDigits())")
                        .font(.system(size: 12))
                        .foregroundColor(appMuted)
                }
                if item.isStale {
                    Text("ذخیره‌شده")
                        .font(.system(size: 12))
                        .foregroundColor(appMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [theme.heroTop, theme.heroBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .padding(.top, 4)
    }
}

struct CategoryHeader: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String

    var body: some View {
        let theme = themeManager.theme
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [theme.accent, theme.accent2],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3, height: 18)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(appText)
            Spacer()
        }
        .padding(.top, 8)
    }
}

struct PriceRow: View {
    let item: PriceItem

    private var sub: String {
        var parts: [String] = []
        if !item.updatedAt.isEmpty { parts.append(item.updatedAt.toFaDigits()) }
        if item.isStale { parts.append("ذخیره‌شده") }
        return parts.joined(separator: " • ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.titleFa)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(appText)
                if !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(appMuted)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 6) {
                Text(item.priceToman.toFaToman())
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(appText)
                ChangePill(item: item, fontSize: 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(appSurface)
        .cornerRadius(16)
    }
}

/// نشان تغییر قیمت — سبز/قرمز با پس‌زمینه‌ی محو
struct ChangePill: View {
    let item: PriceItem
    let fontSize: CGFloat

    var body: some View {
        let positive = item.changeToman >= 0
        let color = positive ? profitGreen : lossRed
        let arrow = positive ? "▲" : "▼"
        Text("\(arrow) \(abs(item.changePercent).toFaPercent())")
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .cornerRadius(8)
    }
}
