import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline

struct PriceEntry: TimelineEntry {
    let date: Date
    let theme: AppTheme
    let dollar: PriceItem?
    let gold18: PriceItem?
    let sekee: PriceItem?
}

struct PriceProvider: TimelineProvider {
    func placeholder(in context: Context) -> PriceEntry {
        PriceEntry(date: Date(), theme: appThemes[0], dollar: nil, gold18: nil, sekee: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PriceEntry) -> Void) {
        Task {
            completion(await makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PriceEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
                ?? Date().addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func makeEntry() async -> PriceEntry {
        let themeId = UserDefaults(suiteName: "group.com.chandeh.app")?.string(forKey: "theme_id")
        let theme = appTheme(id: themeId)
        let items = try? await PriceRepository.fetchPrices()
        return PriceEntry(
            date: Date(),
            theme: theme,
            dollar: items?.first(where: { $0.code == "price_dollar_rl" }),
            gold18: items?.first(where: { $0.code == "geram18" }),
            sekee: items?.first(where: { $0.code == "sekee" })
        )
    }
}

/// تازه‌سازی دستی ویجت
struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "تازه‌سازی ویجت"

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - View

private let widgetMuted = Color(hex: 0x8B93A7)

struct NerkhCheckWidgetView: View {
    let entry: PriceEntry

    var body: some View {
        let theme = entry.theme
        VStack(spacing: 0) {
            // سربرگ
            HStack {
                Button(intent: RefreshWidgetIntent()) {
                    Text("⟳ تازه‌سازی")
                        .font(.system(size: 12))
                        .foregroundColor(theme.accent2)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("NerkhCheck")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.accent)
            }

            if let dollar = entry.dollar {
                Spacer().frame(height: 12)

                HStack(spacing: 8) {
                    Circle()
                        .fill(theme.accent2)
                        .frame(width: 8, height: 8)
                    Text("دلار آمریکا • بازار آزاد")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.accent)
                    Spacer()
                }

                Spacer().frame(height: 8)

                HStack(alignment: .bottom, spacing: 6) {
                    Text(dollar.priceToman.toFaToman())
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white)
                    Text("تومان")
                        .font(.system(size: 14))
                        .foregroundColor(widgetMuted)
                        .padding(.bottom, 4)
                    Spacer()
                }

                Spacer().frame(height: 6)

                HStack(spacing: 8) {
                    let positive = dollar.changeToman >= 0
                    Text("\(positive ? "▲" : "▼") \(abs(dollar.changePercent).toFaPercent())")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(positive ? profitGreen : lossRed)
                    if !dollar.updatedAt.isEmpty {
                        Text("به‌روزرسانی \(dollar.updatedAt.toFaDigits())")
                            .font(.system(size: 12))
                            .foregroundColor(widgetMuted)
                    }
                    Spacer()
                }

                Spacer().frame(height: 10)
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                Spacer().frame(height: 10)

                HStack(alignment: .top) {
                    if let sekee = entry.sekee {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("سکه امامی")
                                .font(.system(size: 12))
                                .foregroundColor(widgetMuted)
                            Text(sekee.priceToman.toFaToman())
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    if let gold18 = entry.gold18 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("طلای ۱۸ عیار")
                                .font(.system(size: 12))
                                .foregroundColor(widgetMuted)
                            Text(gold18.priceToman.toFaToman())
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            } else {
                Spacer()
                Text("در حال دریافت قیمت‌ها...")
                    .font(.system(size: 13))
                    .foregroundColor(widgetMuted)
                Spacer()
            }
        }
        .padding(16)
    }
}

// MARK: - Widget

struct NerkhCheckWidget: Widget {
    let kind: String = "NerkhCheckWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PriceProvider()) { entry in
            NerkhCheckWidgetView(entry: entry)
                .containerBackground(entry.theme.heroTop, for: .widget)
        }
        .configurationDisplayName("NerkhCheck")
        .description("قیمت دلار، طلای ۱۸ عیار و سکه امامی")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct NerkhCheckWidgetBundle: WidgetBundle {
    var body: some Widget {
        NerkhCheckWidget()
    }
}
