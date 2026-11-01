# StockSaathi - Mobile Accessories

Stock register for small mobile accessory shops in India. Track covers, tempered glass, chargers, cables, earphones, power banks, and memory cards, see what is running low, and get the list out as a PDF, an Excel file, or a live Google Sheet.

Built for a shop owner who currently uses a paper register, reads Hindi more comfortably than English, and does not want a complicated app. Flutter, Android, light theme, [Iconsax](https://pub.dev/packages/iconsax_flutter) icons.

## The one rule

**No money fields.** No purchase price, no selling price, no value totals. Not in the database, not in the UI, not in exports, not in the synced Sheet. The app tracks quantity only, and a CI check fails the build if a money field ever appears.

## Install

Grab the latest `.apk` from [Releases](https://github.com/indee289/Rexo-New-app/releases) and open it on the phone. Android 8.0 or newer.

The `.aab` in the same release is for uploading to the Play Console. It will not install on a phone.

## What it does

| Area | Detail |
|---|---|
| Items | Name, category, brand, model, minimum stock, photo, shelf, note. Duplicate name + brand + model is caught before saving. |
| Stock in / out | Big `+` / `-` on the item, plus inline `+` / `-` on every list row. Every change records a reason: new stock, sold, returned, damaged, correction. |
| Undo | Appends a reversing entry. The ledger is never edited or deleted, so history stays auditable. |
| Search and filter | Name, brand, and model search. Filter by category, brand, model, and stock status. Sort by name, quantity, or recently updated. |
| Low stock | Out of stock first, then low stock, worst shortfall at the top. Optional daily reminder on the device. |
| Dashboard | Item count, total quantity, low and out counts, and today's in/out. |
| History | Per item and across the shop, grouped by day or by month, filterable by date range and reason. |
| Export | PDF and `.xlsx`, generated on the phone, shareable to WhatsApp or anywhere. |
| Google Sheet | One-way sync, app to Sheet, with three tabs: Stock, History, Summary. |
| Offline | Everything except sync works with no internet. Pending changes go out when the network returns. |
| Backup | Full local JSON backup and restore. |
| Language | Hindi and English, switchable without restarting. |

## Two things to know about the Sheet sync

**It is one-way.** The Sheet mirrors the app. Editing the Sheet does not change the app, and those edits are overwritten on the next sync. Every tab carries a banner saying so. Two-way sync needs conflict resolution, which is where this kind of app usually loses data, so it waits for Phase 2.

**The app creates the spreadsheet; it cannot attach to an existing one.** The app requests only Google's non-sensitive per-file Drive scope, which covers files the app created or the user explicitly picked. The broader Sheets scope is classified as sensitive and would require completing Google's OAuth verification review before a public release. Avoiding that keeps the launch date predictable, at the cost of the "paste your Sheet link" flow.

## Builds and releases

`.github/workflows/build-apk.yml` runs on every push to `main` and on manual dispatch. It checks that no money field exists, runs the analyzer, fetches the Noto Devanagari font for PDF output, builds a release APK and an app bundle, and publishes both as a GitHub Release tagged `v<version>-<run number>`.

The workflow does not need any secrets to succeed. Without them it signs the release build with the debug key, which installs fine for testing but cannot go to Play.

### Signing secrets

Add these four under **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The keystore file, base64 encoded |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

To create a keystore and get the base64 value:

```bash
keytool -genkey -v -keystore stocksaathi.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias stocksaathi

base64 -w 0 stocksaathi.jks   # paste this into ANDROID_KEYSTORE_BASE64
```

Keep `stocksaathi.jks` safe and out of the repository. Losing it means never being able to update the app on Play under the same identity.

### Turning on Google Sheets sync

Sync needs an OAuth client that Google can match to the installed app. Nothing goes in the repository; it is all console configuration.

1. Create a project at [Google Cloud Console](https://console.cloud.google.com/) and enable the **Google Sheets API** and the **Google Drive API**.
2. Configure the OAuth consent screen. Add only the scope `https://www.googleapis.com/auth/drive.file`, which is non-sensitive and needs no verification review.
3. Create an **OAuth client ID** of type **Android** with:
   - Package name: `com.stocksaathi.app`
   - SHA-1: printed by the **Show release signing SHA-1** step of the workflow once the signing secrets are set. For local debug builds use `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`.
4. Add your own Google account as a test user while the consent screen is unpublished.

Until this is done, the Connect button in Settings will fail at sign-in. Every other feature works without it.

## Architecture

Local SQLite via `sqflite` is the single source of truth, so every feature works offline and sync never sits in the path of a user action. Item quantity is a cached column over an append-only movement ledger, written in one transaction so an app kill mid-write cannot leave the two disagreeing. Settings has a maintenance action that recomputes every cached quantity from the ledger.

There is no backend. The schema still uses UUID keys, `updated_at`, `deleted_at`, and `device_id`, so adding one in Phase 2 for staff logins and multiple shops is additive rather than a migration over live data.

```
lib/
  core/      theme, Iconsax mapping, Hindi/English strings, formatters
  data/      SQLite schema, models, repository, photo store, backup
  services/  PDF, Excel, Google Sheets sync, reminders
  ui/        7 screens plus shared widgets
```

## Local development

```bash
flutter pub get
flutter run
```

For Hindi PDF output, drop `NotoSansDevanagari-Regular.ttf` and `NotoSansDevanagari-Bold.ttf` into `assets/fonts/`. They are deliberately not committed; CI fetches them, and without them the PDF falls back to a font with no Devanagari coverage.

## Documentation

- [`requirements.md`](.kiro/specs/stocksaathi-mvp/requirements.md) - product principles, non-goals, functional requirements with acceptance criteria, pre-launch checklist
- [`design.md`](.kiro/specs/stocksaathi-mvp/design.md) - locked decisions with rejected alternatives, data model, sync algorithm, screen designs, and section 10 recording every deviation the implementation made
- [`tasks.md`](.kiro/specs/stocksaathi-mvp/tasks.md) - task plan and launch plan

## Not verified yet

CI proves the app compiles, analyzes clean, and packages. These need a physical device:

1. Google Sheets sync end to end, which also needs the OAuth client above.
2. The daily reminder actually firing, which varies by phone manufacturer.
3. Camera and gallery capture.
4. Layout at the largest system font scale.

Known limitation: the `pdf` package does not do complex-script shaping, so Devanagari conjuncts and vowel marks can render imperfectly in exported PDFs. The Excel export and the Google Sheet are unaffected.

Open item before the store listing is locked: "Saathi" is common in Indian app names, so the StockSaathi name needs a Play Store and trademark check.
