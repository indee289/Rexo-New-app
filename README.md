# StockSaathi - Mobile Accessories

Stock register for small mobile accessory shops in India. Track covers, tempered glass, chargers, cables, earphones, power banks, and memory cards, see what is running low, and get the list into a PDF, an Excel file, or a live Google Sheet.

Built for a shop owner who currently uses a paper register, reads Hindi more comfortably than English, and does not want a complicated app.

## The one rule

**No prices.** No purchase price, no selling price, no value totals. Not in the database, not in the UI, not in exports, not in the synced Sheet. The app tracks quantity only, and that is what keeps it simple enough to actually get used.

## Phase 1 scope

| In | Out (and when it returns) |
|---|---|
| Add, edit, soft-delete items with category, brand, model, min stock, photo, shelf, note | Prices - never |
| Stock in / out with a reason on every change, and undo | Barcode scanning - Phase 2 |
| Search by name, filter by category / brand / model / status | Two-way Sheet sync - Phase 2 |
| Low stock and out of stock lists, plus an optional daily local notification | OneDrive / Excel Online sync - Phase 2 |
| Dashboard totals and today's movement | Staff logins, multiple shops - Phase 2/3 |
| Full movement history, day-wise and month-wise | WhatsApp alerts - Phase 3 |
| PDF and Excel export, generated on-device | |
| One-way Google Sheets sync, app to Sheet | |
| Works fully offline; local backup and restore | |

## Two decisions worth knowing before reading the code

**Sync is one-way.** The Google Sheet is a read-only mirror of the app. Editing the Sheet does not change the app, and those edits get overwritten on the next sync. Two-way sync needs conflict resolution, which is where this class of app usually loses user data, so it waits for Phase 2.

**The app creates the spreadsheet; it cannot connect to an existing one.** We request only Google's non-sensitive per-file Drive scope, which covers files the app created or the user explicitly picked. The broader Sheets scope is classified as sensitive and would require completing Google's OAuth verification review before a public release. Avoiding that keeps the launch date predictable, at the cost of the "paste your Sheet link" flow.

## Architecture

Flutter, Android first. Local SQLite via Drift is the single source of truth, so every feature works offline and sync is never in the path of a user action. Stock quantity is a cached column derived from an append-only movement ledger. There is no backend in Phase 1, but the schema uses UUID keys, `updated_at`, `deleted_at`, and `device_id` so that adding one in Phase 2 is additive rather than a migration over live data.

## Documentation

- [`requirements.md`](.kiro/specs/stocksaathi-mvp/requirements.md) - product principles, non-goals, functional requirements with acceptance criteria, non-functional targets, pre-launch checklist
- [`design.md`](.kiro/specs/stocksaathi-mvp/design.md) - locked decisions with rejected alternatives, tech stack, full data model, sync algorithm, screen-by-screen design, export layouts
- [`tasks.md`](.kiro/specs/stocksaathi-mvp/tasks.md) - ordered implementation plan and launch plan

## Status

Specification complete. No application code yet.

Open item before the store listing is locked: "Saathi" is a common element in Indian app names, so the StockSaathi name needs a Play Store and trademark check.
