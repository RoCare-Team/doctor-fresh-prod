# Doctor Fresh — Flutter mobile app

The Doctor Fresh app for Android and iOS: shop water purifiers and spares, book a technician, and look after the purifier at home.

What the app does beyond the shop:

- **My purifier** (`lib/screens/purifier_screen.dart`, `lib/core/purifier.dart`): the customer adds their purifier once; the app shows filter and service health as rings, keeps a service history on the phone, and schedules local notifications three days before a service or filter change is due. Tapping one opens the purifier screen.
- **Water check** (`lib/screens/water_check_screen.dart`): a TDS guide that recommends the purification the customer's water needs.
- **Secure in-app payment**: on iOS the Easebuzz page opens on an `SFSafariViewController` sheet inside the app, and the order is checked as soon as it closes.
- Haptic feedback, native date pickers, share sheet, document picker, location, PDF preview.

Catalogue, orders and bookings come from the Doctor Fresh backend (`/api/*`).

**No third-party packages.** `pubspec.yaml` lists only the Flutter SDK. Everything usually done with a plugin is written by hand:

| Need | How it is done here |
|---|---|
| HTTP + session cookie | `dart:io` `HttpClient`, with the `df_session` cookie kept manually (`lib/core/api.dart`) |
| Local storage (cart, pin code, cookies) | A JSON file in the app's private folder (`lib/core/storage.dart`) |
| Rich text (product descriptions, blogs, policies) | A small HTML renderer (`lib/widgets/html_view.dart`) |
| Open links, call, WhatsApp, mail, share, open PDF, pick a file, current location, in-app payment sheet, local reminders | Platform channel `in.doctorfresh.app/native` (`lib/core/native.dart`), implemented in `android/.../MainActivity.kt` + `DfFileProvider.kt` + `Reminders.kt` and `ios/Runner/AppDelegate.swift` |

## Run it

Requirements:
- Flutter **3.47** or newer (Dart 3.13). The code was analysed with Flutter 3.47.7 stable.
- Android Studio (Android SDK) and/or Xcode for iOS.

```bash
cd mobile-app-flutter
flutter pub get          # only the SDK itself; nothing is downloaded from pub.dev
flutter run              # against https://www.doctorfresh.in
```

To run against a local copy of the website (`npm run dev` in the Next.js project):

```bash
flutter run --dart-define=DF_BASE_URL=http://10.0.2.2:3000     # Android emulator
flutter run --dart-define=DF_BASE_URL=http://localhost:3000    # iOS simulator
```

> A plain-`http://` local URL also needs `android:usesCleartextTraffic="true"` on Android (debug only) and an ATS exception on iOS. Production uses https and needs neither.

Release builds:

```bash
flutter build apk --release      # or: flutter build appbundle
flutter build ipa                # on a Mac, after setting the team in Xcode
```

Identifiers: Android `applicationId` / iOS bundle id is `in.doctorfresh.doctor_fresh`, and the display name is "Doctor Fresh".

Before publishing to the stores, set up release signing (Android `key.properties` and a keystore; iOS signing team). Use a high-resolution 1024 px logo for the launcher icons.

## Project layout

```
lib/
  main.dart                 app entry; theme; AppScope
  app_tabs.dart             bottom tab bar: Home · Categories · Services · Cart · Account
  router.dart               website link → app screen (/category/…, /product/…/id, /blogs, /water-purifier-service …)
  core/
    config.dart             base URL, phone / WhatsApp / email
    api.dart                HTTP client + cookie jar
    storage.dart            on-device key/value store
    native.dart             platform channel (links, share, PDF, file picker)
    models.dart             Product, CartLine, ServiceLine, User
    format.dart             ₹ formatting (en-IN), dates, validation patterns
    theme.dart              the website's design tokens (app/globals.css)
  state/app_state.dart      signed-in user, cart, wishlist, service cart, menu data
  widgets/                  header/drawer/footer/contact dock (shell.dart), product cards, forms & sheets, HTML view, UI kit
  screens/
    home_screen.dart        Home tab: greeting + search, promo banners, category circles, services, deals, rails
    categories_tab.dart     Categories tab: category rail on the left, its ranges on the right
    account_tab.dart        Account tab: profile, orders, wishlist, help & support, explore, policies, sign out
    catalog_screens.dart    category / sub-category listing (filters, sort), all categories, search
    product_screen.dart     product detail (gallery, buy box, delivery check, how it works, tabs, reviews, FAQs, related)
    cart_screens.dart       cart, 3-step checkout, online payment hand-off
    account_screens.dart    OTP sign in / register, profile (orders, wishlist, edit), order page
    service_screens.dart    service booking: services, service cart, booking checkout, booking done
    blog_screens.dart       blog list (by category), blog post with comments
    info_screens.dart       contact, become a partner, store locator, careers (CV upload), legal pages
assets/images/              logo, favicon, hero and banner images copied from the website's public/images
```

## Backend endpoints used

All of these live in the Next.js project under `app/api/`.

**Existing website APIs (unchanged):**
- Auth: `/api/auth/request-otp`, `/api/auth/verify-otp`, `/api/auth/me`, `/api/auth/logout`
- Account: `/api/account`, `/api/account/addresses`, `/api/wishlist`, `/api/recently-viewed`, `/api/reviews`
- Checkout: `/api/checkout/quote`, `/api/checkout`, `/api/orders/cancel`, `/api/orders/invoice/{id}`, `/api/pincode/{pin}`
- Services: `/api/services/*` (cities, timeslots, address, payment-options, book, pay-later)
- Leads: `/api/wizard/*`, `/api/forms/*`, `/api/quotation`, `/api/brochure/{id}`, `/api/careers/apply`, `/api/comments`

**Read-only endpoints added for the app** (`app/api/mobile/*`, helpers in `lib/mobile.js`). The website had no API for its catalogue, so these were added. They read the same lib functions the website pages already use, and no existing page or API was changed.

| Endpoint | Returns |
|---|---|
| `GET /api/mobile/home` | everything on the home page (hero tiles, deals, categories, water test, rails, latest / most viewed, services, brand) |
| `GET /api/mobile/menu` | category tree with images and counts, blog categories, legal pages, brand / contact |
| `GET /api/mobile/category?path=cat[/sub]` | a listing page and its products |
| `GET /api/mobile/product/{id}` | full product detail + related products |
| `GET /api/mobile/products?ids=…` / `?q=…` | products by id (wishlist) / search |
| `GET /api/mobile/orders` / `?id=…` | the signed-in customer's orders + profile / one order |
| `GET /api/mobile/services` | bookable services with prices, service groups, states |
| `GET /api/mobile/blog` / `?category=` / `?id=` | blog list / one post |
| `GET /api/mobile/page?type=legal\|stores\|careers` | policy pages, store locator, careers |

**The backend with the `app/api/mobile/*` routes must be deployed before the app is released.** Until then the app's catalogue screens will not load.

## How the main flows work

- **Sign in.** The customer enters their mobile number and gets an OTP (`request-otp`), then enters it (`verify-otp`). The server sets the `df_session` cookie, which the app keeps and sends back on every call.
- **Cart.** The cart is kept on the device, as on the website: under `df_cart_guest` while signed out and `df_cart_user_<id>` once signed in. The guest cart is merged into the user's cart at sign-in. Prices are confirmed by the server at checkout (`/api/checkout/quote`).
- **Online payment (Easebuzz).** There is no WebView, because that would need a package.
  1. `/api/checkout` returns the Easebuzz payment link, and the app opens it in the phone's browser.
  2. When the customer comes back to the app, it checks `/api/mobile/orders?id=<saleId>`.
  3. If the order is paid, the app shows it. If not, it offers "Pay again" and "Check again".

  Cash on delivery goes straight to the order page.
- **Service booking.** The customer signs in, picks services and goes to the service cart. They then fill details and address, choose a date and time slot, and choose payment: pay online in the browser, or pay after the visit. The final screen is "Booking confirmed".
- **Downloads.** An invoice is downloaded with the session cookie and opened in the phone's PDF viewer. A brochure opens in the browser.

## Notes and known differences from the website

- **Font.** The website uses the Inter web font. The app uses the platform font (Roboto on Android, SF on iOS), because no font files are bundled. To match exactly, add the Inter `.ttf` files under `assets/fonts/` and declare them in `pubspec.yaml`.
- **Payment and videos.** Payment pages and demo videos open in the browser or the YouTube app, not inside the app.
- **Location.** The app asks for location permission when it opens and shows the customer's area and pin code at the top of Home (native `location` method → the site's `/api/geo/reverse`). Tapping it looks again. The checkout form still fills city and state from the pin code; it does not use GPS.
#   d o c t o r - f r e s h - p r o d 
 
 