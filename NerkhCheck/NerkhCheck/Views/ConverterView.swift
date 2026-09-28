import SwiftUI

/// «تومان ایران» به‌عنوان واحد پایه — همیشه در دسترس است، حتی قبل از بارگذاری قیمت‌ها
private let tomanItem = PriceItem(
    code: "toman_ir",
    titleFa: "تومان ایران",
    category: .currency,
    priceToman: 1,
    changeToman: 0,
    changePercent: 0,
    updatedAt: ""
)

struct ConverterView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var pricesVM: PricesViewModel

    @State private var amountText = "1"
    @State private var fromCode: String? = nil
    @State private var toCode: String? = tomanItem.code

    private var allItems: [PriceItem] {
        [tomanItem] + pricesVM.items
    }

    private var from: PriceItem? {
        allItems.first(where: { $0.code == fromCode })
    }

    private var to: PriceItem? {
        allItems.first(where: { $0.code == toCode })
    }

    private var amount: Double {
        Double(amountText) ?? 0
    }

    private var result: Double? {
        guard let from = from, let to = to, to.priceToman > 0 else { return nil }
        return amount * Double(from.priceToman) / Double(to.priceToman)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        Text("تبدیل ارز")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(appText)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        TextField("مقدار", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .padding(14)
                            .background(appSurface)
                            .cornerRadius(14)
                            .foregroundColor(appText)
                            .onChange(of: amountText) { _, v in
                                amountText = v.filter { $0.isNumber || $0 == "." }
                            }

                        CurrencyPicker(
                            label: "از",
                            items: allItems,
                            selectedCode: $fromCode
                        )
                        CurrencyPicker(
                            label: "به",
                            items: allItems,
                            selectedCode: $toCode
                        )

                        if let result = result, let from = from, let to = to {
                            Text("\(amountText.isEmpty ? "۰" : amountText.toFaDigits()) \(from.titleFa) = \(result.toFaSmart()) \(to.titleFa)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(appText)
                                .multilineTextAlignment(.center)
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(appSurface)
                                .cornerRadius(14)
                        } else if pricesVM.items.isEmpty {
                            Text("برای تبدیل، اول قیمت‌ها باید بارگذاری شوند.")
                                .font(.system(size: 14))
                                .foregroundColor(appMuted)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("تبدیل")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            // پیش‌فرض: از دلار آمریکا به تومان ایران
            if fromCode == nil {
                fromCode = allItems.first(where: { $0.code == "price_dollar_rl" })?.code
                    ?? allItems.first?.code
            }
            if pricesVM.items.isEmpty {
                await pricesVM.refresh()
            }
        }
    }
}

private struct CurrencyPicker: View {
    let label: String
    let items: [PriceItem]
    @Binding var selectedCode: String?

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(appMuted)
            Spacer()
            Picker(label, selection: $selectedCode) {
                ForEach(items) { item in
                    Text(item.titleFa).tag(Optional(item.code))
                }
            }
            .pickerStyle(.menu)
            .tint(appText)
        }
        .padding(14)
        .background(appSurface)
        .cornerRadius(14)
    }
}
