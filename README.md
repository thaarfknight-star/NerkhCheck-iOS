# NerkhCheck — نسخه‌ی iOS

اپلیکیشن نیتیو iOS برای مشاهده‌ی لحظه‌ای قیمت ارز، طلا و سکه — نوشته‌شده با SwiftUI.

## امکانات

- 📊 قیمت لحظه‌ای ۱۸ نماد: ارزها (دلار، یورو، پوند، ...)، طلا (۱۸/۲۴ عیار، مثقال) و سکه
- 🔄 تبدیل ارز بین همه‌ی نمادها و تومان
- 🎨 شش تم رنگی ترکیب‌شده (شفق قطبی، آتشفشان، کهکشان، ساحل، جنگل، نئون)
- 🧩 ویجت هوم‌اسکرین: دلار، طلای ۱۸ عیار و سکه امامی با دکمه‌ی تازه‌سازی
- 🌙 حالت تیره، رابط کاملاً فارسی و راست‌به‌چپ

## منبع داده

قیمت‌ها از صفحه‌ی اصلی [tgju.org](https://www.tgju.org/) خوانده می‌شوند
(وب‌سرویس عمومی TGJU به‌عنوان منبع جایگزین).

## ساخت

```bash
xcodebuild -scheme NerkhCheck \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

- Display Name: ‏NerkhCheck
- نسخه: 1.0.0 (Build 3)
- Bundle ID: ‏com.chandeh.app
- نیازمند iOS 17 به بالا و Xcode 16

## App Group

اشتراک تم فعال بین اپ و ویجت از طریق App Group انجام می‌شود:

```
group.com.chandeh.app
```

این شناسه باید در تنظیمات Signing هر دو تارگت (اپ و ویجت) فعال باشد.

## لینک‌ها

- گیت‌هاب: https://github.com/thaarfknight-star/Chandeh
- تلگرام: https://t.me/tha_arf
